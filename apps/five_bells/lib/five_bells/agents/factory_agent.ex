defmodule FiveBells.Agents.FactoryAgent do
  use Agent
  require Logger

  alias __MODULE__
  alias FiveBells.Agents.{BankAgent, MarketAgent}

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      output: 1,
      units_sold: 0,
      units_sold_total: 0,
      units_produced: 0,
      units_produced_total: 0,
      current_cycle: 0,
      name: "Factory",
      entity_no: "F-0001",
      recipe: %Recipe{},
      initial_deposit: 0,
      max_inventory: -1,
      initiate_sale: true,
      inventory: [],
      unit_cost: 1,
      market: nil,
      suppliers: %{},
      supplier_type: :market
    ]
  end

  def state(agent), do: Agent.get(agent, & &1)

  #############################################################################
  # Simulation
  #############################################################################

  def start_link(args \\ 0) do
    case Agent.start_link(fn -> struct(State, args) end) do
      {:ok, agent} = resp ->
        case open_deposit_account(agent) do
          :ok -> resp
          err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  def stop(agent), do: Agent.stop(agent)

  def evaluate(agent, cycle, simulation_id \\ "") do
    # record the state of production
    # reset cycle data
    with :ok <- produce(agent),
         :ok <- sell_to_market(agent),
         :ok <- flush_statistics(agent, cycle, simulation_id),
         # :ok <- pay_salaries(agent, cycle, simulation_id),
         # :ok <- hire_fire_employees(agent, cycle, simulation_id),
         :ok <- discard_inventory(agent),
         :ok <- reset_cycle(agent, cycle) do
      :ok
    else
      err ->
        Logger.error("Factory is having problems: #{inspect(err)}")
        err
    end
  end

  def reset_cycle(agent, cycle) do
    Agent.update(agent, fn x -> %{x | units_produced: 0, units_sold: 0, current_cycle: cycle} end)
  end

  #############################################################################
  # Funds
  #############################################################################

  defp bank(agent), do: state(agent).bank
  defp initial_deposit(agent), do: state(agent).initial_deposit

  def account(agent) do
    case BankAgent.get_account(bank(agent), agent) do
      {:ok, account} -> account
      err -> err
    end
  end

  def account_deposit(agent) do
    case BankAgent.get_account_deposit(bank(agent), agent) do
      {:ok, deposit} -> deposit
      err -> err
    end
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(
               bank(agent),
               agent,
               "Factory",
               state(agent).entity_no,
               initial_deposit(agent)
             ) do
          {:ok, account_no} -> Agent.update(agent, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end

  #############################################################################
  # Production
  #############################################################################

  def product_name(agent), do: recipe(agent).product_name
  defp recipe(agent), do: state(agent).recipe

  def available_quantity?(agent, quantity) do
    output_remaining(agent) >= quantity
  end

  defp can_output?(agent) do
    output_remaining(agent) > 0 && max_items(agent) > 0 && production_capacity(agent) > 0
  end

  defp units_produced(agent), do: state(agent).units_produced
  defp units_produced_total(agent), do: state(agent).units_produced_total
  defp output_remaining(agent), do: state(agent).output - units_produced(agent)
  defp unit_cost(agent), do: state(agent).unit_cost
  defp afford_output(agent), do: round(account_deposit(agent) / unit_cost(agent))

  def production_capacity(agent) do
    # things to consider
    # 1. how much output do we have remaining given our current staff
    # 2. how much can we afford to produce
    # 3. how much can we store
    output_remains = output_remaining(agent)
    afford_output = afford_output(agent)
    max_items = max_items(agent)

    min(
      min(output_remains, afford_output),
      max_items
    )
  end

  def produce(agent), do: produce_capacity(agent)
  def produce(agent, quantity), do: produce_quantity(agent, quantity)

  def produce_quantity(agent, quantity) do
    case output_remaining(agent) >= quantity do
      true ->
        # Go to our suppliers and get the necessary components
        case acquire_components(agent, state(agent).recipe.components, quantity) do
          {:ok, _components} ->
            produced = Enum.map(1..quantity, fn _ -> Recipe.produce(state(agent).recipe) end)

            Agent.update(agent, fn x ->
              %{
                x
                | units_produced_total: x.units_produced_total + length(produced),
                  units_produced: x.units_produced + length(produced),
                  inventory: x.inventory ++ produced
              }
            end)

          err ->
            err
        end

      false ->
        {:error, {:unable_to_produce_quantity, quantity, output_remaining(agent)}}
    end
  end

  def produce_capacity(agent) do
    case can_output?(agent) do
      true ->
        # How much can we actually produce?
        quantity = production_capacity(agent)

        # Go to our suppliers and get the necessary components
        case acquire_components(agent, state(agent).recipe.components, quantity) do
          {:ok, _components} ->
            produced = Enum.map(1..quantity, fn _ -> Recipe.produce(state(agent).recipe) end)

            Agent.update(agent, fn x ->
              %{
                x
                | units_produced_total: x.units_produced_total + length(produced),
                  units_produced: x.units_produced + length(produced),
                  inventory: x.inventory ++ produced
              }
            end)

          err ->
            err
        end

      false ->
        :ok
    end
  end

  def acquire_components(agent, names, quantity \\ 1, purchased \\ %{}) do
    case state(agent).supplier_type do
      :market ->
        with :ok <- check_market_availability(agent, names, quantity),
             {:ok, _} = resp <- purchase_market_components(agent, names, quantity, purchased) do
          resp
        else
          err -> err
        end

      :factory ->
        with :ok <- check_factory_availability(agent, names, quantity),
             {:ok, _} = resp <- purchase_factory_components(agent, names, quantity, purchased) do
          resp
        else
          err -> err
        end
    end
  end

  # market purchase

  def check_market_availability(_agent, _names, _quantity \\ 1)
  def check_market_availability(_agent, [], _quantity), do: :ok

  def check_market_availability(agent, [name | tail], quantity) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        with {:ok, _available} <- MarketAgent.available_quantity?(supplier, quantity),
             :ok <- check_market_availability(agent, tail, quantity) do
          :ok
        else
          err -> err
        end
    end
  end

  def purchase_market_components(_agent, _names, _quantity \\ 1, _purchased \\ %{})
  def purchase_market_components(_agent, [], _quantity, purchased), do: {:ok, purchased}

  def purchase_market_components(agent, [name | tail], quantity, purchased) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        case MarketAgent.sell_to_customer(supplier, agent, quantity) do
          {:ok, products} ->
            purchase_market_components(
              agent,
              tail,
              quantity,
              Map.put_new(purchased, name, products)
            )

          err ->
            err
        end
    end
  end

  # factory purchase

  def check_factory_availability(_agent, _names, _quantity \\ 1)
  def check_factory_availability(_agent, [], _quantity), do: :ok

  def check_factory_availability(agent, [name | tail], quantity) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        with true <- FactoryAgent.available_quantity?(supplier, quantity),
             :ok <- check_factory_availability(agent, tail, quantity) do
          :ok
        else
          err -> err
        end
    end
  end

  def purchase_factory_components(_agent, _names, _quantity \\ 1, _purchased \\ %{})
  def purchase_factory_components(_agent, [], _quantity, purchased), do: {:ok, purchased}

  def purchase_factory_components(agent, [name | tail], quantity, purchased) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        case FactoryAgent.sell_to_factory(supplier, agent, quantity) do
          {:ok, products} ->
            purchase_market_components(
              agent,
              tail,
              quantity,
              Map.put_new(purchased, name, products)
            )

          err ->
            err
        end
    end
  end

  #############################################################################
  # Inventory
  #############################################################################

  defp keep_inventory?(agent), do: state(agent).max_inventory > 0
  defp inventory(agent), do: state(agent).inventory
  defp inventory_count(agent), do: length(state(agent).inventory)
  defp max_inventory(agent), do: state(agent).max_inventory
  defp max_items(agent), do: max_inventory(agent) - inventory_count(agent)

  def discard_inventory(agent) do
    case keep_inventory?(agent) do
      false -> Agent.update(agent, fn x -> %{x | inventory: []} end)
      true -> :ok
    end
  end

  #############################################################################
  # Sales
  #############################################################################

  defp initiates_sale?(agent), do: state(agent).initiate_sale
  defp market(agent), do: state(agent).market
  defp units_sold(agent), do: state(agent).units_sold
  defp units_sold_total(agent), do: state(agent).units_sold_total

  # market sales

  def set_market(agent, market), do: Agent.update(agent, fn x -> %{x | market: market} end)

  def sell_to_market(agent, buyer, quantity, price) when price > 0 and quantity > 0 do
    case inventory_count(agent) >= quantity do
      true ->
        with :ok <-
               BankAgent.transfer(
                 bank(agent),
                 buyer,
                 agent,
                 price * quantity,
                 "#{FactoryAgent.state(agent).entity_no} selling #{quantity} units to #{
                   MarketAgent.state(buyer).entity_no
                 }"
               ),
             {:ok, products} <- remove_from_inventory(agent, quantity),
             :ok <- MarketAgent.receive_delivery(buyer, products) do
          Agent.update(agent, fn x ->
            %{
              x
              | units_sold: x.units_sold + quantity,
                units_sold_total: x.units_sold_total + quantity
            }
          end)
        else
          err ->
            BankAgent.transfer(
              bank(agent),
              buyer,
              agent,
              price * quantity,
              "Refunding to customer"
            )

            err
        end

      false ->
        {:error, :unable_to_supply_quantity}
    end
  end

  def sell_to_market(agent) do
    case initiates_sale?(agent) do
      true ->
        buyer = market(agent)
        price = MarketAgent.bid_price(market(agent))
        quantity = min(MarketAgent.purchase_capacity(market(agent)), inventory_count(agent))

        # we are only interested in selling to markets that are willing to pay and can receive something
        cond do
          quantity > 0 && price > 0 ->
            sell_to_market(agent, buyer, quantity, price)

          true ->
            :ok
        end

      false ->
        :ok
    end
  end

  # factory sales

  def sell_to_factory(agent, buyer, quantity \\ 1, price \\ 1)
      when is_pid(buyer) and price > 0 and quantity > 0 do
    # Factory sales are paid in advance to ensure there are funds for the purchase
    # of the required components
    with :ok <-
           BankAgent.transfer(
             bank(agent),
             buyer,
             agent,
             price * quantity,
             "#{FactoryAgent.state(agent).entity_no} selling #{quantity} units to #{
               FactoryAgent.state(buyer).entity_no
             }"
           ),
         :ok <- produce_quantity(agent, quantity),
         {:ok, _products} <- remove_from_inventory(agent, quantity) do
      Agent.update(agent, fn x ->
        %{
          x
          | units_sold: x.units_sold + quantity,
            units_sold_total: x.units_sold_total + quantity
        }
      end)
    else
      err -> err
    end
  end

  #############################################################################
  # Delivery
  #############################################################################

  defp remove_from_inventory(agent, quantity) do
    case length(inventory(agent)) >= quantity do
      true ->
        {outgoing, remaining} = Enum.split(inventory(agent), quantity)
        {Agent.update(agent, fn x -> %{x | inventory: remaining} end), outgoing}

      false ->
        {:error, :out_of_stock}
    end
  end

  #############################################################################
  # Statistics
  #############################################################################

  defp flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_production_statistics(agent, cycle, simulation_id),
         :ok <- flush_sales_statistics(agent, cycle, simulation_id),
         :ok <- flush_inventory_statistics(agent, cycle, simulation_id),
         :ok <- flush_account_status(agent, cycle, simulation_id) do
      :ok
    else
      err -> err
    end
  end

  defp flush_production_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.units_produced",
               product_name(agent),
               units_produced(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.units_produced_total",
               product_name(agent),
               units_produced_total(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.output_remaining",
               product_name(agent),
               # correct for this being recorded after the inventory might have been sold
               output_remaining(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp flush_sales_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.units_sold",
               product_name(agent),
               units_sold(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.units_sold_total",
               product_name(agent),
               units_sold_total(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp flush_inventory_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "factory.inventory_count",
               product_name(agent),
               inventory_count(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  def flush_account_status(agent, cycle, simulation_id) do
    account = account(agent)

    case FiveBells.Repo.insert(%FiveBells.Banks.Deposit{
           bank_no: BankAgent.state(bank(agent)).bank_no,
           account_no: account.account_no,
           owner_type: "Factory",
           owner_id: state(agent).entity_no,
           deposit: account.deposit,
           delta: account.delta,
           cycle: cycle,
           simulation_id: simulation_id
         }) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp create_time_series_entry(agent, label, key, value, cycle, simulation_id) do
    %FiveBells.Statistics.TimeSeries{
      label: label,
      key: key,
      entity_type: "Factory",
      entity_id: state(agent).entity_no,
      value: value,
      cycle: cycle,
      simulation_id: simulation_id
    }
  end
end

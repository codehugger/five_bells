defmodule FiveBells.Agents.FactoryAgent do
  use Agent
  require Logger

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
      factory_no: "F-0001",
      recipe: %Recipe{},
      initial_deposit: 0,
      max_inventory: -1,
      initiate_sale: true,
      inventory: [],
      unit_cost: 1,
      market: nil,
      suppliers: %{}
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
               state(agent).factory_no,
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

  def produce(agent) do
    case can_output?(agent) do
      true ->
        # How much can we actually produce?
        quantity = production_capacity(agent)

        if quantity == 0 do
          IO.puts("Quantity being produced #{quantity}")
          IO.puts("Max items is #{max_items(agent)}")
          IO.puts("Output remaining is #{output_remaining(agent)}")
          IO.puts("Afford output is #{afford_output(agent)}")
        end

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

          _ ->
            :ok
        end

      false ->
        :ok
    end
  end

  def acquire_components(agent, names, quantity \\ 1, purchased \\ %{}) do
    with :ok <- check_component_availability(agent, names, quantity),
         {:ok, _} = resp <- purchase_components(agent, names, quantity, purchased) do
      resp
    else
      err -> err
    end
  end

  def check_component_availability(_agent, _names, _quantity \\ 1)
  def check_component_availability(_agent, [], _quantity), do: :ok

  def check_component_availability(agent, [name | tail], quantity) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        with {:ok, _available} <- MarketAgent.available_quantity?(supplier, quantity),
             :ok <- check_component_availability(agent, tail, quantity) do
          :ok
        else
          err -> err
        end
    end
  end

  def purchase_components(_agent, _names, _quantity \\ 1, _purchased \\ %{})
  def purchase_components(_agent, [], _quantity, purchased), do: {:ok, purchased}

  def purchase_components(agent, [name | tail], quantity, purchased) do
    case state(agent).suppliers[name] do
      nil ->
        {:error, {:no_supplier_for_component, name}}

      supplier ->
        case MarketAgent.sell_to_customer(supplier, agent, quantity) do
          {:ok, products} ->
            purchase_components(agent, tail, quantity, Map.put_new(purchased, name, products))

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

  def set_market(agent, market), do: Agent.update(agent, fn x -> %{x | market: market} end)

  def sell_to_customer(agent, buyer, quantity \\ 1, price \\ 1)
      when is_pid(buyer) and price > 0 and quantity > 0 do
    case inventory_count(agent) >= quantity do
      true ->
        with :ok <-
               BankAgent.transfer(
                 bank(agent),
                 buyer,
                 agent,
                 price * quantity,
                 "Selling to customer"
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
    # sell as much as the market is willing to accept and we can provide
    # price is decided by market through bid price
    capacity = min(MarketAgent.purchase_capacity(market(agent)), inventory_count(agent))

    case initiates_sale?(agent) && capacity > 0 do
      true ->
        sell_to_customer(
          agent,
          market(agent),
          capacity,
          MarketAgent.bid_price(market(agent))
        )

      false ->
        :ok
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
           owner_id: state(agent).factory_no,
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
      entity_id: state(agent).factory_no,
      value: value,
      cycle: cycle,
      simulation_id: simulation_id
    }
  end
end

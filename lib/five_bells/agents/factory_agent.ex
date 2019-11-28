defmodule FactoryAgent do
  use Agent
  import Logger

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
      recipe: %Recipe{},
      initial_deposit: 0,
      max_inventory: -1,
      initiate_sale: true,
      inventory: [],
      unit_cost: 1,
      market: nil
    ]
  end

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

  def account_deposit(agent) do
    case BankAgent.get_account_deposit(bank(agent), agent) do
      {:ok, deposit} -> deposit
      err -> err
    end
  end

  def state(agent), do: Agent.get(agent, & &1)
  def bank(agent), do: state(agent).bank
  def recipe(agent), do: state(agent).recipe
  def inventory(agent), do: state(agent).inventory
  def inventory_count(agent), do: length(state(agent).inventory)
  def max_inventory(agent), do: state(agent).max_inventory
  def max_items(agent), do: max(max_inventory(agent) - inventory_count(agent), 3)
  def units_produced(agent), do: state(agent).units_produced
  def units_produced_total(agent), do: state(agent).units_produced_total
  def units_sold(agent), do: state(agent).units_sold
  def units_sold_total(agent), do: state(agent).units_sold_total
  def market(agent), do: state(agent).market
  def initial_deposit(agent), do: state(agent).initial_deposit
  def initiates_sale?(agent), do: state(agent).initiate_sale
  def keep_inventory?(agent), do: state(agent.max_inventory) <= 0
  def output_remaining(agent), do: state(agent).output - units_produced(agent)
  def can_output?(agent), do: output_remaining(agent) > 0
  def unit_cost(agent), do: state(agent).unit_cost

  def set_market(agent, market), do: Agent.update(agent, fn x -> %{x | market: market} end)

  def production_capacity(agent) do
    # things to consider
    # 1. how much output do we have remaining given our current staff
    # 2. how much can we afford to produce
    # 3. how much can we store
    min(
      min(output_remaining(agent), round(account_deposit(agent) / unit_cost(agent))),
      max_items(agent)
    )
  end

  def produce(agent) do
    case can_output?(agent) do
      true ->
        produced =
          Enum.map(1..production_capacity(agent), fn _ -> Recipe.produce(recipe(agent)) end)

        Agent.update(agent, fn x ->
          %{
            x
            | output: x.output - length(produced),
              units_produced_total: x.units_produced_total + length(produced),
              units_produced: x.units_produced + length(produced),
              inventory: x.inventory ++ produced
          }
        end)

      false ->
        :ok
    end
  end

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

    case capacity > 0 do
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

  def evaluate(agent, cycle, simulation_id \\ "") do
    # record the state of production
    # reset cycle data
    with :ok <- produce(agent),
         :ok <- sell_to_market(agent),
         :ok <- flush_statistics(agent, cycle, simulation_id),
         :ok <- reset_cycle(agent, cycle) do
      :ok
    else
      err ->
        Logger.error("Factory is having problems: #{inspect(err)}")
        err
    end
  end

  def flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_production_statistics(agent, cycle, simulation_id),
         :ok <- flush_sales_statistics(agent, cycle, simulation_id),
         :ok <- flush_inventory_statistics(agent, cycle, simulation_id) do
      :ok
    else
      err -> err
    end
  end

  def flush_production_statistics(agent, cycle, simulation_id) do
    factory = state(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.units_produced.#{factory.name}",
               units_produced(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.units_produced_total.#{factory.name}",
               units_produced_total(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.output_remaining.#{factory.name}",
               # correct for this being recorded after the inventory might have been sold
               output_remaining(agent) + units_produced(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  def flush_sales_statistics(agent, cycle, simulation_id) do
    factory = state(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.units_sold.#{factory.name}",
               units_sold(agent),
               cycle,
               simulation_id
             )
           ),
         {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.units_sold_total.#{factory.name}",
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

  def flush_inventory_statistics(agent, cycle, simulation_id) do
    factory = state(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               "factory.inventory_count.#{factory.name}",
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

  def reset_cycle(agent, cycle) do
    Agent.update(agent, fn x -> %{x | units_produced: 0, units_sold: 0, current_cycle: cycle} end)
  end

  defp remove_from_inventory(agent, quantity) do
    case length(inventory(agent)) >= quantity do
      true ->
        {outgoing, remaining} = Enum.split(inventory(agent), quantity)
        {Agent.update(agent, fn x -> %{x | inventory: remaining} end), outgoing}

      false ->
        {:error, :out_of_stock}
    end
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(bank(agent), agent, initial_deposit(agent)) do
          {:ok, account_no} -> Agent.update(agent, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end

  defp create_time_series_entry(label, value, cycle, simulation_id) do
    %Repo.TimeSeries{label: label, value: value, cycle: cycle, simulation_id: simulation_id}
  end
end

defmodule FactoryAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      output: 1,
      units_produced: 0,
      units_produced_total: 0,
      current_cycle: 0,
      name: "Factory",
      recipe: %Recipe{},
      initial_deposit: 0,
      max_inventory: 0,
      sell_to_market: true,
      inventory: []
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

  def state(agent), do: Agent.get(agent, & &1)
  def bank(agent), do: state(agent).bank
  def recipe(agent), do: state(agent).recipe
  def inventory(agent), do: state(agent).inventory
  def inventory_count(agent), do: length(state(agent).inventory)
  def units_produced(agent), do: state(agent).units_produced
  def units_produced_total(agent), do: state(agent).units_produced_total
  def market(agent), do: state(agent).market
  def initial_deposit(agent), do: state(agent).initial_deposit
  def sells_to_market?(agent), do: state(agent).sell_to_market
  def keep_inventory?(agent), do: state(agent.max_inventory) <= 0
  def output_remaining(agent), do: state(agent).output - state(agent).units_produced
  def can_output?(agent), do: output_remaining(agent) > 0

  def produce(agent, quantity \\ 1) do
    IO.puts("Producing #{quantity}")

    case can_output?(agent) do
      true ->
        Agent.update(agent, fn x ->
          %{
            x
            | output: x.output - quantity,
              units_produced_total: x.units_produced_total + quantity,
              units_produced: x.units_produced + quantity
          }
        end)

        [Recipe.produce(recipe(agent))]

      false ->
        []
    end
  end

  def sell_to_customer(agent, buyer, quantity \\ 1, price \\ 1) when is_pid(buyer) do
    IO.puts("Selling to customer #{quantity}")

    case BankAgent.transfer(bank(agent), buyer, agent, price * quantity, "Selling to customer") do
      :ok ->
        {:ok, produce(agent, quantity)}

      err ->
        IO.inspect(err)
        err
    end
  end

  def evaluate(agent, cycle, simulation_id \\ "") do
    # record the state of production
    # reset cycle data
    with :ok <- flush_statistics(agent, cycle, simulation_id),
         :ok <- reset_cycle(agent, cycle) do
      :ok
    else
      err -> err
    end
  end

  def flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_production_statistics(agent, cycle, simulation_id),
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
    Agent.update(agent, fn x -> %{x | units_produced: 0, current_cycle: cycle} end)
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

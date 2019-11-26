defmodule FactoryAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      output: 1,
      units_produced: 1,
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
  def market(agent), do: state(agent).market
  def initial_deposit(agent), do: state(agent).initial_deposit
  def sells_to_market?(agent), do: state(agent).sell_to_market
  def keep_inventory?(agent), do: state(agent.max_inventory) <= 0
  def can_output?(agent), do: state(agent).units_produced < state(agent).output

  def produce(agent, quantity \\ 1) do
    case can_output?(agent) do
      false ->
        Agent.update(agent, fn x ->
          %{x | output: x.output - quantity, units_produced: x.units_produced + quantity}
        end)

        [Recipe.produce(recipe(agent))]

      true ->
        nil
    end
  end

  def sell_to_customer(agent, buyer, _quantity \\ 1, _price \\ 0) when is_pid(buyer) do
    case BankAgent.transfer(bank(agent), buyer, agent, 1) do
      :ok -> {:ok, produce(agent)}
      err -> err
    end
  end

  def evaluate(agent, cycle, _simulation_id \\ "") do
    with :ok <- reset_cycle(agent, cycle) do
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
end

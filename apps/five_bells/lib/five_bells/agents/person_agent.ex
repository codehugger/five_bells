defmodule FiveBells.Agents.PersonAgent do
  use Agent

  alias FiveBells.Agents.{BankAgent, MarketAgent}

  defmodule State do
    defstruct [:name, :entity_no, :bank, :market, :account_no, initial_deposit: 0, consumed: %{}]
  end

  def state(agent), do: Agent.get(agent, & &1)

  #############################################################################
  # Simulation
  #############################################################################

  def start_link(args) do
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

  def evaluate(agent, cycle, simulation_id) do
    case purchase(agent) do
      {:ok, product} ->
        consume(agent, product)

      {:error, _} = err ->
        err
    end

    flush_statistics(agent, cycle, simulation_id)
  end

  #############################################################################
  # Funds
  #############################################################################

  def bank(agent), do: Agent.get(agent, & &1.bank)
  def initial_deposit(agent), do: Agent.get(agent, & &1.initial_deposit)

  def account(agent) do
    {:ok, account} = BankAgent.get_account(bank(agent), agent)
    account
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(
               bank(agent),
               agent,
               "Person",
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
  # Consumption
  #############################################################################

  def consumed_total(agent) do
    Enum.reduce(state(agent).consumed, 0, fn {_key, val}, sum -> sum + val end)
  end

  def consume(agent, product) do
    # IO.puts("#{state(agent).name} consumed #{inspect(product)}")
    Agent.update(agent, fn x ->
      %{x | consumed: Map.update(x.consumed, product.name, 1, fn x -> x + 1 end)}
    end)
  end

  #############################################################################
  # Purchase
  #############################################################################

  def market(agent), do: Agent.get(agent, & &1.market)

  def purchased_total(_agent), do: 0

  def purchase(agent) do
    deposit = account(agent).deposit
    price = MarketAgent.sell_price(market(agent))

    cond do
      deposit < price ->
        # IO.puts("#{name(agent)} cannot afford product at price #{price}")
        {:error, :cannot_afford_product}

      deposit == 0 ->
        # IO.puts("#{name(agent)} has no funds")
        {:error, :no_funds}

      true ->
        case MarketAgent.sell_to_customer(market(agent), agent, 1) do
          {:ok, [product | _]} = _resp ->
            IO.puts("#{state(agent).name} bought #{inspect(product)} at #{price}")
            {:ok, product}

          {:error, reason} = err ->
            IO.puts(
              "#{state(agent).name} unable to acquired product from market #{inspect(reason)}"
            )

            err
        end
    end
  end

  #############################################################################
  # Statistics
  #############################################################################

  defp flush_statistics(agent, cycle, simulation_id) do
    with :ok <- flush_account_statistics(agent, cycle, simulation_id),
         :ok <- flush_purchase_statistics(agent, cycle, simulation_id),
         :ok <- flush_consumption_statistics(agent, cycle, simulation_id),
         :ok <- flush_account_status(agent, cycle, simulation_id) do
      :ok
    else
      err -> err
    end
  end

  defp flush_account_statistics(agent, cycle, simulation_id) do
    account = account(agent)

    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "person.account_deposit",
               account.deposit,
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp flush_purchase_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "person.purchased_total",
               purchased_total(agent),
               cycle,
               simulation_id
             )
           ) do
      :ok
    else
      err -> err
    end
  end

  defp flush_consumption_statistics(agent, cycle, simulation_id) do
    with {:ok, _} <-
           FiveBells.Repo.insert(
             create_time_series_entry(
               agent,
               "person.consumed_total",
               consumed_total(agent),
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
           owner_type: "Person",
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

  defp create_time_series_entry(agent, label, value, cycle, simulation_id) do
    person = state(agent)

    %FiveBells.Statistics.TimeSeries{
      entity_type: "Person",
      entity_id: "#{person.name}",
      label: label,
      key: "#{person.name}",
      value: value,
      cycle: cycle,
      simulation_id: simulation_id
    }
  end
end

defmodule PersonAgent do
  use Agent

  defmodule State do
    defstruct [:name, :bank, :market, :account_no, initial_deposit: 0, consumed: []]
  end

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

  def state(agent), do: Agent.get(agent, & &1)
  def name(agent), do: Agent.get(agent, & &1.name)
  def bank(agent), do: Agent.get(agent, & &1.bank)
  def market(agent), do: Agent.get(agent, & &1.market)
  def initial_deposit(agent), do: Agent.get(agent, & &1.initial_deposit)

  def account(agent), do: BankAgent.get_account(bank(agent), agent)
  def account_deposit(agent), do: BankAgent.get_account_deposit(bank(agent), agent)
  def account_no(agent), do: BankAgent.get_account_no(bank(agent), agent)

  def consume(agent, product) do
    # IO.puts("#{state(agent).name} consumed #{inspect(product)}")
    Agent.update(agent, fn x -> %{x | consumed: [product | x.consumed]} end)
  end

  def purchase(agent) do
    {:ok, deposit} = account_deposit(agent)
    price = MarketAgent.price_to_customer(market(agent))

    cond do
      deposit < price ->
        # IO.puts("#{name(agent)} cannot afford product at price #{price}")
        {:error, :cannot_afford_product}

      deposit == 0 ->
        # IO.puts("#{name(agent)} has no funds")
        {:error, :no_funds}

      true ->
        case MarketAgent.sell_to_customer(market(agent), agent) do
          {:ok, _product} = resp ->
            # IO.puts("#{name(agent)} bought #{inspect(product)} at #{price}")
            resp

          {:error, _reason} = err ->
            # IO.puts("#{name(agent)} unable to acquired product from market #{inspect(reason)}")
            err
        end
    end
  end

  def evaluate(agent, _cycle, _simulation_id) do
    case purchase(agent) do
      {:ok, product} ->
        consume(agent, product)

      {:error, _} = err ->
        err
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
end

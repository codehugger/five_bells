defmodule PersonAgent do
  use Agent

  defmodule State do
    defstruct [:name, :bank, :market, :account_no, initial_deposit: 0, consumed: []]
  end

  def start_link(_name, bank \\ BankAgent, market \\ MarketAgent, args \\ [])

  def start_link(name, bank, market, args)
      when is_atom(bank) and is_atom(market) and is_list(args) do
    start_link(name, Process.whereis(bank), Process.whereis(market), args)
  end

  def start_link(name, bank, market, args) when is_pid(bank) and is_list(args) do
    case Agent.start_link(fn ->
           struct(State, [name: name, bank: bank, market: market] ++ args)
         end) do
      {:ok, person} = resp ->
        case open_deposit_account(person) do
          :ok -> resp
          err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  def state(person), do: Agent.get(person, & &1)
  def bank(person), do: Agent.get(person, & &1.bank)
  def market(person), do: Agent.get(person, & &1.market)
  def initial_deposit(person), do: Agent.get(person, & &1.initial_deposit)

  def account(person), do: BankAgent.get_account(person)
  def account_deposit(person), do: BankAgent.get_account_deposit(person)
  def account_no(person), do: BankAgent.get_account_no(person)

  def consume(person, product) do
    # IO.puts("Consumed #{inspect(product)}")
    Agent.update(person, fn x -> %{x | consumed: [product | x.consumed]} end)
  end

  def purchase(person) do
    case account_deposit(person) do
      {:ok, 0} ->
        IO.puts("#{state(person).name} no funds")
        {:error, :no_funds}

      _ ->
        case MarketAgent.purchase(person) do
          {:ok, _} = resp ->
            # IO.puts("Bought #{inspect(product)}")
            resp

          {:error, _} = err ->
            err
        end
    end
  end

  def evaluate(person, _cycle) do
    case purchase(person) do
      {:ok, product} ->
        consume(person, product)

      {:error, _} = err ->
        err
    end
  end

  defp open_deposit_account(person) do
    cond do
      bank(person) != nil ->
        case BankAgent.open_deposit_account(person, initial_deposit(person)) do
          {:ok, account_no} -> Agent.update(person, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end
end

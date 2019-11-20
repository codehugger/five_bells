defmodule BankAgent do
  use Agent

  defmodule State do
    defstruct [:bank, account_registry: %{}]
  end

  def start_link(name, central_bank \\ nil) do
    case %Bank{name: name, central_bank: central_bank}
         |> Bank.init_customer_bank_ledgers() do
      {:ok, bank} -> Agent.start_link(fn -> %State{bank: bank} end)
      err -> err
    end
  end

  def stop(agent), do: Agent.stop(agent)

  def state(agent), do: Agent.get(agent, & &1)
  def account_registry(agent), do: Agent.get(agent, & &1.account_registry)

  def get_account(agent, account_no) when is_binary(account_no),
    do: Bank.get_account(state(agent).bank, account_no)

  def get_account(agent, owner_no) when is_pid(owner_no) do
    case account_registry(agent)[owner_no] do
      nil -> {:error, :unrecognized_owner}
      account_no -> Bank.get_account(state(agent).bank, account_no)
    end
  end

  def get_account_deposit(agent, account_no) do
    case get_account(agent, account_no) do
      {:ok, account} -> account.deposit
      err -> err
    end
  end

  def open_deposit_account(agent, owner_no) do
    case Bank.open_deposit_account(state(agent).bank, owner_no) do
      {:ok, bank} -> Agent.update(agent, fn _ -> bank end)
      err -> err
    end
  end

  def deposit_cash(agent, account_no, amount) do
    case state(agent).bank |> Bank.deposit_cash(account_no, amount) do
      {:ok, bank} -> Agent.update(agent, fn _ -> bank end)
      err -> err
    end
  end

  def transfer(agent, from_no, to_no, amount) do
    case Bank.transfer(state(agent).bank, from_no, to_no, amount) do
      {:ok, bank} -> Agent.update(agent, fn _ -> bank end)
    end
  end
end

defmodule BankAgent do
  use Agent

  def start_link(name, central_bank \\ nil) do
    {:ok, bank} =
      %Bank{name: name, central_bank: central_bank}
      |> Bank.init_customer_bank_ledgers()

    Agent.start_link(fn -> bank end)
  end

  def stop(agent) do
    Agent.stop(agent)
  end

  def bank(agent) do
    Agent.get(agent, & &1)
  end

  def account(agent, account_no) do
    Bank.get_account(bank(agent), account_no)
  end

  def open_deposit_account(agent, owner_no) do
    case Bank.open_deposit_account(bank(agent), owner_no) do
      {:ok, bank} -> Agent.update(agent, fn _ -> bank end)
      {:error, _} = error -> error
    end
  end

  def deposit_cash(agent, account_no, amount) do
    case bank(agent) |> Bank.deposit_cash(account_no, amount) do
      {:ok, bank} -> Agent.update(agent, fn _ -> bank end)
      {:error, _} = error -> error
    end
  end
end

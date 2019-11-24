defmodule BorrowerAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      loan_amount: 0,
      loan_duration: 0,
      initial_deposit: 0
    ]
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
  def bank(agent), do: state(agent).bank
  def initial_deposit(agent), do: state(agent).initial_deposit
  def loan_amount(agent), do: state(agent).loan_amount
  def borrower_window(agent), do: state(agent).borrower_window

  def evaluate(agent, _cycle) do
    case BankAgent.get_loan(bank(agent), agent) do
      true ->
        IO.puts("Paying back loan")

      false ->
        BankAgent.request_loan(bank(agent), agent, loan_amount(agent))
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

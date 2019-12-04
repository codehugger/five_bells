defmodule FiveBells.Agents.BorrowerAgent do
  use Agent

  alias FiveBells.Agents.{BankAgent}

  defmodule State do
    defstruct [
      :bank,
      :account_no,
      :person_no,
      loan_amount: 0,
      loan_duration: 12,
      interest_rate: 0.0,
      initial_deposit: 0
    ]
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
    case BankAgent.get_loan(bank(agent), agent) do
      {:ok, _loan} ->
        case BankAgent.pay_loan(bank(agent), agent) do
          {:error, :insufficient_funds} ->
            # Force the bank to hire the borrower
            BankAgent.hire_borrower(bank(agent), agent)

          resp ->
            resp
        end

      {:error, :loan_not_found} ->
        BankAgent.request_loan(
          bank(agent),
          agent,
          loan_amount(agent),
          loan_duration(agent),
          interest_rate(agent)
        )
    end

    flush_account_status(agent, cycle, simulation_id)
  end

  #############################################################################
  # Loan details
  #############################################################################

  defp loan_amount(agent), do: state(agent).loan_amount
  defp loan_duration(agent), do: state(agent).loan_duration
  defp interest_rate(agent), do: state(agent).interest_rate

  #############################################################################
  # Funds
  #############################################################################

  def bank(agent), do: state(agent).bank
  def initial_deposit(agent), do: state(agent).initial_deposit

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

  def account(agent) do
    {:ok, account} = BankAgent.get_account(bank(agent), agent)
    account
  end

  #############################################################################
  # Statistics
  #############################################################################

  def flush_account_status(agent, cycle, simulation_id) do
    account = account(agent)

    case FiveBells.Repo.insert(%FiveBells.Banks.Deposit{
           bank_no: BankAgent.state(bank(agent)).bank_no,
           account_no: account.account_no,
           owner_type: "Borrower",
           owner_id: state(agent).person_no,
           deposit: account.deposit,
           delta: account.delta,
           cycle: cycle,
           simulation_id: simulation_id
         }) do
      {:ok, _} -> :ok
      err -> err
    end
  end
end

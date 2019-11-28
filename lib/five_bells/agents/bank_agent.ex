defmodule BankAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      # account_registry - owner => account_no
      account_registry: %{},
      # owner_registry - account_no => owner
      owner_registry: %{},
      # a special set of employees that get a salary based on outstanding debt
      borrowers: []
      # a reference to the current simulation
    ]
  end

  def state(agent), do: Agent.get(agent, & &1)
  def bank(agent), do: state(agent).bank

  #############################################################################
  # Simulation
  #############################################################################

  def start_link(args \\ []) do
    case Bank.init_customer_bank_ledgers(struct(Bank, args)) do
      {:ok, bank} -> Agent.start_link(fn -> struct(State, [bank: bank] ++ args) end)
      err -> err
    end
  end

  def stop(agent), do: Agent.stop(agent)

  def evaluate(agent, cycle, simulation_id \\ "") do
    # fire borrowers who have paid their debts
    fire_borrowers(agent)

    # pay borrowers salaries so they can afford their next payments
    Enum.each(borrowers(agent), fn b ->
      # get total of next payment
      {:ok, loan} = get_loan(agent, b)
      {:ok, payment} = Loan.next_payment(loan)
      {:ok, deposit} = get_account_deposit(agent, "interest_income")

      case deposit > 0 do
        true ->
          # transfer amount from interest_income to borrower as salary
          transfer(
            agent,
            "interest_income",
            b,
            min(LoanPayment.total(payment), deposit),
            "Borrower salary payment"
          )

        false ->
          nil
      end
    end)

    # flush cycle statistics like transactions
    flush_statistics(agent, cycle, simulation_id)

    # flush transactions to db
    flush_transactions(agent, cycle, simulation_id)

    # reset all cycle data
    reset_cycle(agent, cycle, simulation_id)
  end

  #############################################################################
  # Accounts
  #############################################################################

  def account_registry(agent), do: state(agent).account_registry
  def owner_registry(agent), do: state(agent).owner_registry

  def get_account_no(agent, owner) when is_pid(owner) do
    case account_registry(agent)[owner] do
      nil -> {:error, :unrecognized_owner}
      account_no -> {:ok, account_no}
    end
  end

  def get_account(agent, account_no) when is_binary(account_no) do
    Bank.get_account(bank(agent), account_no)
  end

  def get_account(agent, owner) when is_pid(owner) do
    case get_account_no(agent, owner) do
      {:ok, account_no} -> Bank.get_account(bank(agent), account_no)
      err -> err
    end
  end

  def get_account_deposit(agent, owner) when is_pid(owner) do
    case get_account(agent, owner) do
      {:ok, account} -> {:ok, account.deposit}
      err -> err
    end
  end

  def get_account_deposit(agent, account_no) when is_binary(account_no) do
    case get_account(agent, account_no) do
      {:ok, account} -> {:ok, account.deposit}
      err -> err
    end
  end

  def get_account_delta(agent, owner) when is_pid(owner) do
    case get_account_no(agent, owner) do
      {:ok, account_no} -> get_account_delta(agent, account_no)
      err -> err
    end
  end

  def get_account_delta(agent, account_no) when is_binary(account_no) do
    case get_account(agent, account_no) do
      {:ok, account} -> {:ok, account.delta}
      err -> err
    end
  end

  def open_deposit_account(agent, owner, initial_deposit \\ 0)
      when is_pid(owner) and is_number(initial_deposit) do
    case Bank.open_deposit_account(bank(agent)) do
      {:ok, bank, account_no} ->
        # Update bank after account is added
        Agent.update(agent, fn x -> %{x | bank: bank} end)

        # Register account_no to pid of owner
        register_account_ownership(agent, owner, account_no)

        # Deposit cash if there is an initial deposit
        cond do
          initial_deposit > 0 ->
            BankAgent.deposit_cash(agent, account_no, initial_deposit)
            {:ok, account_no}

          true ->
            {:ok, account_no}
        end

      err ->
        err
    end
  end

  defp register_account_ownership(agent, owner, account_no)
       when is_pid(owner) and is_binary(account_no) do
    Agent.update(agent, fn x ->
      %{
        x
        | account_registry: Map.put(x.account_registry, owner, account_no),
          owner_registry: Map.put(x.owner_registry, account_no, owner)
      }
    end)
  end

  #############################################################################
  # Loans
  #############################################################################

  def loan_registry(agent), do: state(agent).loan_registry

  def has_debt?(agent, customer) do
    case get_loan(agent, customer) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def get_loan(agent, owner) when is_pid(owner) do
    case get_account_no(agent, owner) do
      {:ok, account_no} -> get_loan(agent, account_no)
      err -> err
    end
  end

  def get_loan(agent, account_no) when is_binary(account_no) do
    Bank.get_loan(bank(agent), account_no)
  end

  def pay_loan(agent, borrower) do
    with {:ok, account_no} <- get_account_no(agent, borrower),
         {:ok, bank} <- Bank.pay_loan(bank(agent), account_no) do
      Agent.update(agent, fn x -> %{x | bank: bank} end)
    else
      err ->
        err
    end
  end

  def request_loan(agent, borrower, amount, duration \\ 12, interest_rate \\ 0.0) do
    with {:ok, account_no} <- get_account_no(agent, borrower),
         {:ok, bank} <-
           Bank.request_loan(bank(agent), account_no, amount, duration, interest_rate) do
      Agent.update(agent, fn x -> %{x | bank: bank} end)
    else
      err -> err
    end
  end

  #############################################################################
  # Transfers
  #############################################################################

  def deposit_cash(agent, owner, amount) when is_pid(owner) and amount > 0 do
    case get_account_no(agent, owner) do
      {:ok, account_no} -> deposit_cash(agent, account_no, amount)
      err -> err
    end
  end

  def deposit_cash(agent, account_no, amount) when is_binary(account_no) and amount > 0 do
    case Bank.deposit_cash(bank(agent), account_no, amount) do
      {:ok, bank} -> Agent.update(agent, fn x -> %{x | bank: bank} end)
      err -> err
    end
  end

  def transfer(agent, from, to, amount, text \\ "")

  def transfer(agent, from_owner, to_owner, amount, text)
      when is_pid(from_owner) and is_pid(to_owner) and amount > 0 do
    with {:ok, from_no} <- get_account_no(agent, from_owner),
         {:ok, to_no} <- get_account_no(agent, to_owner) do
      transfer(agent, from_no, to_no, amount, text)
    else
      err -> err
    end
  end

  def transfer(agent, from_owner, to_no, amount, text)
      when is_pid(from_owner) and is_binary(to_no) do
    case get_account_no(agent, from_owner) do
      {:ok, from_no} -> transfer(agent, from_no, to_no, amount, text)
      err -> err
    end
  end

  def transfer(agent, from_no, to_owner, amount, text)
      when is_binary(from_no) and is_pid(to_owner) do
    case get_account_no(agent, to_owner) do
      {:ok, to_no} -> transfer(agent, from_no, to_no, amount, text)
      err -> err
    end
  end

  def transfer(agent, from_no, to_no, amount, text)
      when is_binary(from_no) and is_binary(to_no) and amount > 0 do
    case Bank.transfer(bank(agent), from_no, to_no, amount, text) do
      {:ok, bank} -> Agent.update(agent, fn x -> %{x | bank: bank} end)
      err -> err
    end
  end

  #############################################################################
  # Borrowers
  #############################################################################

  def borrowers(agent), do: state(agent).borrowers

  def hire_borrower(agent, borrower) do
    Agent.update(agent, fn x -> Map.update(x, :borrowers, [borrower], &[borrower | &1]) end)
  end

  def fire_borrowers(agent) do
    borrowers = Enum.filter(borrowers(agent), fn b -> BankAgent.has_debt?(agent, b) end)
    Agent.update(agent, fn x -> %{x | borrowers: borrowers} end)
  end

  #############################################################################
  # Cleanup
  #############################################################################

  defp flush_transactions(agent, cycle, simulation_id) do
    # transform the transaction structs into maps that can be bulk inserted
    transactions =
      Enum.map(bank(agent).transactions, fn t ->
        Map.from_struct(t)
        |> Map.merge(%{cycle: cycle, bank: bank(agent).name, simulation_id: simulation_id})
      end)

    FiveBells.Repo.insert_all(Repo.Transaction, transactions)

    # clear the flushed transactions from the underlying bank module
    clear_transactions(agent)
  end

  defp reset_cycle(agent, _cycle, _simulation_id) do
    reset_deltas(agent)
  end

  defp clear_transactions(agent) do
    Agent.update(agent, fn x -> %{x | bank: Bank.clear_transactions(x.bank)} end)
  end

  defp reset_deltas(agent) do
    Agent.update(agent, fn x -> %{x | bank: Bank.reset_deltas(x.bank)} end)
  end

  #############################################################################
  # Statistics
  #############################################################################

  defp flush_statistics(agent, cycle, simulation_id) do
    # banks (deposits, loans)
    flush_bank_statistics(agent, cycle, simulation_id)

    # accounts (delta, total)
    flush_account_statistics(agent, cycle, simulation_id)

    # ledgers (delta, total)
    flush_ledger_statistics(agent, cycle, simulation_id)

    # loans (capital/interest -> paid/unpaid)
    flush_loan_statistics(agent, cycle, simulation_id)
  end

  defp flush_bank_statistics(agent, cycle, simulation_id) do
    bank = bank(agent)

    # total deposits
    FiveBells.Repo.insert(%Repo.TimeSeries{
      label: "bank.total_deposit.#{bank.bank_no}",
      value: Bank.total_deposits(bank),
      cycle: cycle,
      simulation_id: simulation_id
    })

    # total loan capital
    FiveBells.Repo.insert(%Repo.TimeSeries{
      label: "bank.total_outstanding_capital.#{bank.bank_no}",
      value: Bank.total_outstanding_capital(bank),
      cycle: cycle,
      simulation_id: simulation_id
    })
  end

  defp flush_ledger_statistics(agent, cycle, simulation_id) do
    bank = bank(agent)

    Enum.each(bank.ledgers, fn {ledger_name, ledger} ->
      FiveBells.Repo.insert(%Repo.TimeSeries{
        label: "ledger.delta.#{bank.bank_no}-#{ledger_name}",
        value: ledger.delta,
        cycle: cycle,
        simulation_id: simulation_id
      })

      # TODO: fix the ledger->account->loan situation!!!
      # FiveBells.Repo.insert(%Repo.TimeSeries{
      #   label: "ledger.total.#{bank.bank_no}-#{ledger_name}",
      #   value: -1,
      #   cycle: cycle,
      #   simulation_id: simulation_id
      # })
    end)
  end

  defp flush_account_statistics(agent, cycle, simulation_id) do
    bank = bank(agent)

    Enum.each(bank.ledgers, fn {ledger_name, ledger} ->
      # Store account deltas
      FiveBells.Repo.insert_all(
        Repo.TimeSeries,
        Enum.map(ledger.accounts, fn {account_no, account} ->
          %{
            label: "account.delta.#{bank.bank_no}-#{ledger_name}-#{account_no}",
            value: account.delta,
            cycle: cycle,
            simulation_id: simulation_id
          }
        end)
      )

      # Store account deposits
      FiveBells.Repo.insert_all(
        Repo.TimeSeries,
        Enum.map(ledger.accounts, fn {account_no, account} ->
          %{
            label: "account.deposit.#{bank.bank_no}-#{ledger_name}-#{account_no}",
            value: account.deposit,
            cycle: cycle,
            simulation_id: simulation_id
          }
        end)
      )
    end)
  end

  defp flush_loan_statistics(agent, _cycle, _simulation_id) do
    Enum.each(bank(agent).unpaid_loans, fn {_account_no, _loan} ->
      nil
      # IO.inspect(loan)
    end)
  end
end

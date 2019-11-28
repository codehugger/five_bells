defmodule Bank do
  defstruct [
    :central_bank,
    ledgers: %{},
    unpaid_loans: %{},
    paid_loans: %{},
    transactions: []
  ]

  #############################################################################
  # Loans
  #############################################################################

  def pay_loan(%Bank{} = bank, account_no) do
    with {:ok, loan} <- get_loan(bank, account_no),
         {:ok, account} <- get_account(bank, account_no),
         {:ok, payment} <- Loan.next_payment(loan) do
      case account.deposit >= LoanPayment.total(payment) do
        true ->
          with {:ok, bank} <-
                 transfer(
                   bank,
                   account_no,
                   "loan",
                   payment.capital,
                   "Loan - capital payment"
                 ),
               {:ok, bank} <-
                 transfer(
                   bank,
                   account_no,
                   "interest_income",
                   payment.interest,
                   "Loan - interest payment"
                 ),
               {:ok, loan} <- Loan.make_payment(loan) do
            case Loan.paid_off?(loan) do
              false ->
                {:ok, %{bank | unpaid_loans: Map.put(bank.unpaid_loans, account_no, loan)}}

              true ->
                {:ok,
                 %{
                   bank
                   | unpaid_loans: Map.delete(bank.unpaid_loans, account_no),
                     paid_loans: Map.update(bank.paid_loans, account_no, [loan], &[loan | &1])
                 }}
            end
          else
            err -> err
          end

        false ->
          {:error, :insufficient_funds}
      end
    else
      err -> err
    end
  end

  def next_payment(%Bank{} = bank, account_no) do
    case get_loan(bank, account_no) do
      {:ok, loan} -> {:ok, Loan.next_payment(loan)}
      err -> err
    end
  end

  def request_loan(
        %Bank{} = bank,
        account_no,
        amount,
        duration \\ 12,
        interest_rate \\ 0.0
      ) do
    case bank.unpaid_loans[account_no] do
      nil ->
        loan =
          %Loan{
            principal: amount,
            duration: duration,
            interest_rate: interest_rate
          }
          |> Loan.calculate_payments()

        case transfer(bank, "loan", account_no, amount, "Loan request transfer") do
          {:ok, bank} ->
            {:ok, %{bank | unpaid_loans: Map.put_new(bank.unpaid_loans, account_no, loan)}}

          err ->
            err
        end

      _ ->
        {:error, :account_has_outstanding_loan}
    end
  end

  def get_loan(%Bank{} = bank, account_no, type \\ :unpaid) do
    loan =
      case type do
        :unpaid -> bank.unpaid_loans[account_no]
        :paid -> bank.paid_loans[account_no]
      end

    case loan do
      nil -> {:error, :loan_not_found}
      loan -> {:ok, loan}
    end
  end

  #############################################################################
  # Transfers
  #############################################################################

  def deposit_cash(%Bank{} = bank, account_no, amount, text \\ "Cash deposit") do
    case get_account(bank, account_no) do
      {:ok, _} -> transfer(bank, "cash", account_no, amount, text)
      {:error, _} = err -> err
    end
  end

  def transfer(bank, debit_no, credit_no, amount, text \\ "")

  # it is sooooo much easier to write code that just ignores zero transactions :)
  def transfer(%Bank{} = bank, _, _, amount, _) when amount == 0, do: {:ok, bank}

  def transfer(%Bank{} = bank, debit_no, credit_no, amount, text) do
    with {:ok, bank} <- credit(bank, credit_no, amount),
         {:ok, bank} <- debit(bank, debit_no, amount),
         {:ok, bank} <- register_transaction(bank, debit_no, credit_no, amount, text) do
      {:ok, bank}
    else
      {:error, _} = err -> err
    end
  end

  defp credit(%Bank{} = bank, account_no, amount) do
    with {:ok, ledger} <- get_ledger(bank, account_no),
         {:ok, ledger} <- Ledger.credit(ledger, account_no, amount) do
      {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger.name, ledger)}}
    else
      err -> err
    end
  end

  defp debit(%Bank{} = bank, account_no, amount) do
    with {:ok, ledger} <- get_ledger(bank, account_no),
         {:ok, ledger} <- Ledger.debit(ledger, account_no, amount) do
      {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger.name, ledger)}}
    else
      err -> err
    end
  end

  defp register_transaction(%Bank{} = bank, deb_no, cred_no, amount, text) do
    {:ok,
     %{
       bank
       | transactions: [
           %Transaction{
             deb_no: deb_no,
             cred_no: cred_no,
             amount: amount,
             text: text
           }
           | bank.transactions
         ]
     }}
  end

  #############################################################################
  # Ledgers
  #############################################################################

  def add_ledger(%Bank{} = bank, name, ledger_type, account_type) do
    case Map.has_key?(bank.ledgers, name) do
      true ->
        {:error, {:ledger_already_exists, name}}

      false ->
        {:ok,
         %{
           bank
           | ledgers:
               Map.put(bank.ledgers, name, %Ledger{
                 name: name,
                 ledger_type: ledger_type,
                 account_type: account_type
               })
         }}
    end
  end

  def get_ledger(%Bank{} = bank, account_no) do
    case bank.ledgers |> Enum.find(fn {_name, ledger} -> ledger.accounts[account_no] end) do
      nil -> {:error, {:ledger_not_found, [account_no: account_no]}}
      {_name, ledger} -> {:ok, ledger}
    end
  end

  #############################################################################
  # Accounts
  #############################################################################

  def add_account(
        %Bank{} = bank,
        ledger_name,
        account_no \\ nil
      )
      when is_binary(ledger_name) do
    case bank.ledgers[ledger_name] do
      nil ->
        {:error, {:ledger_not_found, ledger_name}}

      ledger ->
        case Ledger.add_account(ledger, account_no) do
          {:ok, ledger, acc_no} ->
            {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger_name, ledger)}, acc_no}

          {:error, _} = error ->
            error
        end
    end
  end

  def get_account(%Bank{} = bank, account_no) do
    case bank.ledgers
         # collect all account registries from all ledgers
         |> Enum.map(fn {_name, ledger} -> ledger.accounts end)
         # merge the accounts into one registry
         |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)
         # get the account from the map if it exists
         |> Map.get(account_no) do
      nil -> {:error, :account_not_found}
      account -> {:ok, account}
    end
  end

  def open_deposit_account(%Bank{} = bank) do
    case add_account(bank, "deposit") do
      {:ok, _bank, _account_no} = resp -> resp
      {:error, _} = error -> error
    end
  end

  #############################################################################
  # Init
  #############################################################################

  def init_customer_bank_ledgers(%Bank{} = bank) do
    with {:ok, bank} <- add_ledger(bank, "deposit", "deposit", "liability"),
         # Cash
         {:ok, bank} <- add_ledger(bank, "cash", "cash", "asset"),
         {:ok, bank, _} <- add_account(bank, "cash", "cash"),
         # Loans
         {:ok, bank} <- add_ledger(bank, "loan", "loan", "asset"),
         {:ok, bank, _} <- add_account(bank, "loan", "loan"),
         {:ok, bank} <- add_ledger(bank, "interest_income", "interest_income", "liability"),
         {:ok, bank, _} <- add_account(bank, "interest_income", "interest_income") do
      {:ok, bank}
    else
      {:error, _} = error -> error
    end
  end

  def init_central_bank_ledgers(%Bank{} = bank) do
    {:ok, bank}
  end

  #############################################################################
  # Cleanup
  #############################################################################

  def clear_transactions(%Bank{} = bank) do
    %{bank | transactions: []}
  end

  def reset_deltas(%Bank{} = bank) do
    %{
      bank
      | ledgers:
          Map.new(bank.ledgers, fn {name, ledger} -> {name, Ledger.reset_deltas(ledger)} end)
    }
  end

  #############################################################################
  # Statistics
  #############################################################################

  def total_deposits(%Bank{} = bank) do
    case bank.ledgers["deposit"] do
      nil ->
        {:error, :no_deposit_ledger}

      ledger ->
        Ledger.get_deposit_total(ledger)
    end
  end

  def total_outstanding_capital(%Bank{} = bank) do
    Enum.reduce(bank.unpaid_loans, 0, fn {_acc_no, loan}, sum ->
      sum + Loan.outstanding_capital(loan)
    end)
  end
end

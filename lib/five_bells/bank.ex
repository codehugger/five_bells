defmodule Bank do
  defstruct [
    :central_bank,
    name: "Bank",
    ledgers: %{},
    loans: %{},
    paid_loans: %{},
    transactions: []
  ]

  def open_deposit_account(%Bank{} = bank) do
    case add_account(bank, "deposit") do
      {:ok, _bank, _account_no} = resp -> resp
      {:error, _} = error -> error
    end
  end

  def deposit_cash(%Bank{} = bank, account_no, amount) do
    case get_account(bank, account_no) do
      {:ok, _} -> transfer(bank, "cash", account_no, amount)
      {:error, _} = err -> err
    end
  end

  def pay_loan(%Bank{} = bank, account_no) do
    case get_loan(bank, account_no) do
      {:ok, loan} ->
        payment = Loan.next_payment(loan)

        with {:ok, bank} <- transfer(bank, account_no, "loan", payment.capital),
             {:ok, bank} <- transfer(bank, account_no, "interest_income", payment.interest),
             {:ok, loan} <- Loan.make_payment(loan) do
          case Loan.paid_off?(loan) do
            false ->
              {:ok, %{bank | loans: Map.put(bank.loans, account_no, loan)}}

            true ->
              {:ok,
               %{
                 bank
                 | loans: Map.delete(bank.loans, account_no),
                   paid_loans: Map.update(bank.paid_loans, account_no, [loan], &[loan | &1])
               }}
          end
        else
          err -> err
        end

      err ->
        err
    end
  end

  def request_loan(%Bank{} = bank, account_no, amount) do
    case bank.loans[account_no] do
      nil ->
        loan = %Loan{principal: amount, duration: 1} |> Loan.calculate_payments()

        case transfer(bank, "loan", account_no, amount) do
          {:ok, bank} -> {:ok, %{bank | loans: Map.put_new(bank.loans, account_no, loan)}}
          err -> err
        end

      _ ->
        {:error, :account_has_outstanding_loan}
    end
  end

  def transfer(%Bank{} = bank, _, _, amount) when amount == 0 do
    {:ok, bank}
  end

  def transfer(%Bank{} = bank, debit_no, credit_no, amount) do
    with {:ok, bank} <- credit(bank, credit_no, amount),
         {:ok, bank} <- debit(bank, debit_no, amount),
         {:ok, bank} <- register_transaction(bank, debit_no, credit_no, amount) do
      {:ok, bank}
    else
      {:error, _} = err -> err
    end
  end

  def get_ledger(%Bank{} = bank, account_no) do
    case bank.ledgers |> Enum.find(fn {_name, ledger} -> ledger.accounts[account_no] end) do
      nil -> {:error, {:ledger_not_found, [account_no: account_no]}}
      {_name, ledger} -> {:ok, ledger}
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

  def get_loan(%Bank{} = bank, account_no) do
    case bank.loans[account_no] do
      nil -> {:error, :loan_not_found}
      loan -> {:ok, loan}
    end
  end

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

  defp register_transaction(%Bank{} = bank, deb_no, cred_no, amount) do
    {:ok,
     %{
       bank
       | transactions: [
           %Transaction{deb_no: deb_no, cred_no: cred_no, amount: amount} | bank.transactions
         ]
     }}
  end
end

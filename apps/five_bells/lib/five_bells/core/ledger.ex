defmodule Ledger do
  @account_polarity %{"asset" => -1, "liability" => 1, "equity" => 1}

  defstruct [
    :name,
    ledger_type: "cash",
    account_type: "asset",
    accounts: %{},
    unpaid_loans: %{},
    paid_loans: %{},
    delta: 0
  ]

  #############################################################################
  # Accounts
  #############################################################################

  def add_account(%Ledger{} = ledger), do: add_account(ledger, nil)
  def add_account(_ledger, _account_no \\ nil, _owner_type \\ nil, _owner_id \\ nil)

  def add_account(%Ledger{} = ledger, account_no, owner_type, owner_id)
      when account_no == nil do
    add_account(ledger, generate_account_no(ledger), owner_type, owner_id)
  end

  def add_account(%Ledger{accounts: accounts} = ledger, account_no, owner_type, owner_id)
      when is_binary(account_no) do
    case Map.has_key?(accounts, account_no) do
      true ->
        {:error, {:account_exists, account_no}}

      false ->
        {:ok,
         %{
           ledger
           | accounts:
               Map.put(accounts, account_no, %Account{
                 account_no: account_no,
                 owner_type: owner_type,
                 owner_id: owner_id
               })
         }, account_no}
    end
  end

  defp generate_account_no(%Ledger{} = ledger) do
    "#{length(Map.keys(ledger.accounts)) + 1}"
    |> String.pad_leading(4, "0")
  end

  #############################################################################
  # Loans
  #############################################################################

  def request_loan(%Ledger{} = ledger, account_no, amount, duration, interest_rate) do
    loan =
      %Loan{
        principal: amount,
        duration: duration,
        interest_rate: interest_rate
      }
      |> Loan.calculate_payments()

    add_loan(ledger, account_no, loan)
  end

  def add_loan(%Ledger{} = ledger, account_no, %Loan{} = loan) do
    case ledger.unpaid_loans[account_no] do
      nil ->
        {:ok, %{ledger | unpaid_loans: Map.put_new(ledger.unpaid_loans, account_no, loan)}}

      _ ->
        {:error, :account_has_outstanding_loan}
    end
  end

  def make_payment(%Ledger{} = ledger, account_no, %Loan{} = loan) do
    case Loan.paid_off?(loan) do
      false ->
        {:ok,
         %{
           ledger
           | unpaid_loans: Map.put(ledger.unpaid_loans, account_no, loan)
         }}

      true ->
        {:ok,
         %{
           ledger
           | unpaid_loans: Map.delete(ledger.unpaid_loans, account_no),
             paid_loans:
               Map.update(
                 ledger.paid_loans,
                 account_no,
                 [loan],
                 &[loan | &1]
               )
         }}
    end
  end

  #############################################################################
  # Double-Entry Bookkeeping
  #############################################################################

  def debit(%Ledger{} = ledger, account_no, amount) do
    ledger |> post(account_no, amount * -1)
  end

  def credit(%Ledger{} = ledger, account_no, amount) do
    ledger |> post(account_no, amount)
  end

  defp polarity(%Ledger{} = ledger) do
    case @account_polarity[ledger.account_type] do
      nil -> 0
      polarity -> polarity
    end
  end

  defp post(%Ledger{accounts: accounts} = ledger, account_no, amount) do
    case accounts[account_no] do
      nil ->
        {:error, :account_not_found}

      account ->
        total_amount = account.deposit + amount * polarity(ledger)
        delta = total_amount - account.deposit

        case total_amount < 0 do
          true ->
            {:error, :insufficient_funds}

          false ->
            {:ok,
             %{
               ledger
               | delta: ledger.delta + delta,
                 accounts:
                   Map.update!(ledger.accounts, account_no, fn acc ->
                     %{acc | deposit: total_amount, delta: acc.delta + delta}
                   end)
             }}
        end
    end
  end

  #############################################################################
  # Statistics
  #############################################################################

  def get_deposit_total(%Ledger{} = ledger) do
    Enum.reduce(ledger.accounts, 0, fn {_acc_no, acc}, sum -> sum + acc.deposit end)
  end

  # TODO: loans need to be moved under accounts before attempting this!!!
  # def total(%Ledger{} = ledger) do
  #   case {ledger.ledger_type, ledger.account_type} do
  #   end
  # end

  #############################################################################
  # Cleanup
  #############################################################################

  def reset_deltas(%Ledger{} = ledger) do
    %{
      ledger
      | delta: 0,
        accounts:
          Map.new(ledger.accounts, fn {name, account} -> {name, %{account | delta: 0}} end)
    }
  end
end

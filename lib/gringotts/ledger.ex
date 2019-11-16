defmodule Ledger do
  @account_polarity %{"asset" => -1, "liability" => 1, "equity" => 1}

  defstruct [
    :name,
    ledger_type: "cash",
    account_type: "asset",
    accounts: %{}
  ]

  def add_account(%Ledger{accounts: accounts} = ledger, account_no, owner_no) do
    case Map.has_key?(accounts, account_no) do
      true ->
        {:error, {:account_exists, account_no}}

      false ->
        {:ok,
         %{
           ledger
           | accounts:
               Map.put(accounts, account_no, %Account{account_no: account_no, owner_no: owner_no})
         }}
    end
  end

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

        case total_amount < 0 do
          true -> {:error, :insufficient_funds}
          false -> {:ok, put_in(ledger.accounts[account_no].deposit, total_amount)}
        end
    end
  end
end

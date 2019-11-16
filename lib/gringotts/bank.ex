defmodule Bank do
  defstruct name: "Main Bank", ledgers: %{}

  # TODO: REFACTOR THIS SHIT!!!
  def open_deposit_account(%Bank{} = bank, owner_no) when is_binary(owner_no) do
    add_account(bank, "deposit", owner_no)
  end

  def deposit_cash(%Bank{ledgers: ledgers} = bank, account_no, amount) do
    IO.inspect(get_account(bank, account_no))

    case get_account(bank, account_no) do
      {:error, _} = error ->
        error

      _ ->
        with {:ok, credit_ledger} <- Ledger.credit(ledgers["deposit"], account_no, amount),
             {:ok, debit_ledger} <- Ledger.debit(ledgers["cash"], "cash", amount) do
          {:ok,
           put_in(
             bank.ledgers,
             bank.ledgers
             |> put_in(["cash"], debit_ledger)
             |> put_in(["deposit"], credit_ledger)
           )}
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
      account -> account
    end
  end

  def add_ledger(%Bank{} = bank, name, ledger_type, account_type) do
    case Map.has_key?(bank.ledgers, name) do
      true ->
        {:error, {:ledger_already_exists, name}}

      false ->
        # set the polarity
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

  def add_account(%Bank{} = bank, ledger_name, owner_no \\ "internal") do
    case bank.ledgers[ledger_name] do
      nil ->
        {:error, {:ledger_not_found, ledger_name}}

      ledger ->
        account_no =
          case ledger_name do
            "deposit" -> "#{length(Map.keys(ledger.accounts)) + 1}" |> String.pad_leading(4, "0")
            _ -> ledger_name
          end

        case Ledger.add_account(ledger, account_no, owner_no) do
          {:ok, ledger} -> {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger_name, ledger)}}
          {:error, _} = error -> error
        end
    end
  end

  def init_ledgers(%Bank{} = bank) do
    with {:ok, bank} <- add_ledger(bank, "deposit", "deposit", "liability"),
         {:ok, bank} <- add_ledger(bank, "cash", "cash", "asset"),
         {:ok, bank} <- add_account(bank, "cash") do
      {:ok, bank}
    end
  end
end

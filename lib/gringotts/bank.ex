defmodule Bank do
  defstruct [:central_bank, name: "Main Bank", ledgers: %{}]

  def open_deposit_account(%Bank{} = bank, owner_no) when is_binary(owner_no) do
    case add_account(bank, "deposit", owner_no) do
      {:ok, _} = resp -> resp
      {:error, _} = error -> error
    end
  end

  def deposit_cash(%Bank{} = bank, account_no, amount) do
    case get_account(bank, account_no) do
      {:ok, _} -> transfer(bank, "cash", account_no, amount)
      {:error, _} = err -> err
    end
  end

  def transfer(%Bank{} = bank, debit_no, credit_no, amount) do
    with {:ok, bank} <- credit(bank, credit_no, amount),
         {:ok, bank} <- debit(bank, debit_no, amount) do
      {:ok, bank}
    else
      err -> err
    end
  end

  defp credit(%Bank{} = bank, account_no, amount) do
    with {:ok, ledger} = get_ledger(bank, account_no),
         {:ok, ledger} = Ledger.credit(ledger, account_no, amount) do
      {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger.name, ledger)}}
    end
  end

  defp debit(%Bank{} = bank, account_no, amount) do
    with {:ok, ledger} = get_ledger(bank, account_no),
         {:ok, ledger} = Ledger.debit(ledger, account_no, amount) do
      {:ok, %{bank | ledgers: Map.put(bank.ledgers, ledger.name, ledger)}}
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

  def init_customer_bank_ledgers(%Bank{} = bank) do
    with {:ok, bank} <- add_ledger(bank, "deposit", "deposit", "liability"),
         {:ok, bank} <- add_ledger(bank, "cash", "cash", "asset"),
         {:ok, bank} <- add_account(bank, "cash") do
      {:ok, bank}
    else
      {:error, _} = error -> error
    end
  end

  def init_central_bank_ledgers(%Bank{} = bank) do
    {:ok, bank}
  end
end

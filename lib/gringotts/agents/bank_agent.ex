defmodule BankAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      # account_registry - owner_no => account_no
      account_registry: %{},
      # owner_registry - account_no => owner_no
      owner_registry: %{}
    ]
  end

  def start_link do
    case %Bank{name: __MODULE__}
         |> Bank.init_customer_bank_ledgers() do
      {:ok, bank} -> Agent.start_link(fn -> %State{bank: bank} end, name: __MODULE__)
      err -> err
    end
  end

  def stop, do: Agent.stop(__MODULE__)

  def state, do: Agent.get(__MODULE__, & &1)
  def bank, do: Agent.get(__MODULE__, & &1.bank)
  def account_registry, do: Agent.get(__MODULE__, & &1.account_registry)
  def owner_registry, do: Agent.get(__MODULE__, & &1.owner_registry)

  def get_account_no(owner_no) when is_pid(owner_no) do
    case account_registry()[owner_no] do
      nil -> {:error, :unrecognized_owner}
      account_no -> {:ok, account_no}
    end
  end

  def get_account(account_no) when is_binary(account_no) do
    Bank.get_account(bank(), account_no)
  end

  def get_account(owner_no) when is_pid(owner_no) do
    case get_account_no(owner_no) do
      {:ok, account_no} -> Bank.get_account(bank(), account_no)
      err -> err
    end
  end

  def get_account_deposit(owner_no) when is_pid(owner_no) do
    case get_account(owner_no) do
      {:ok, account} -> {:ok, account.deposit}
      err -> err
    end
  end

  def get_account_deposit(account_no) when is_binary(account_no) do
    case get_account(account_no) do
      {:ok, account} -> account.deposit
      err -> err
    end
  end

  def open_deposit_account(owner_no) when is_pid(owner_no) do
    with {:ok, bank, account_no} <- Bank.open_deposit_account(bank()),
         :ok <-
           Agent.update(__MODULE__, fn x ->
             %{
               x
               | bank: bank,
                 account_registry: Map.put(x.account_registry, owner_no, account_no),
                 owner_registry: Map.put(x.owner_registry, account_no, owner_no)
             }
           end) do
      {:ok, account_no}
    else
      err -> err
    end
  end

  def open_deposit_account(owner_no, initial_deposit \\ 0)
      when is_pid(owner_no) and is_number(initial_deposit) do
    case BankAgent.open_deposit_account(owner_no) do
      {:ok, account_no} = resp ->
        case initial_deposit > 0 do
          true ->
            case BankAgent.deposit_cash(account_no, initial_deposit) do
              :ok -> resp
              err -> err
            end

          false ->
            resp
        end

      err ->
        err
    end
  end

  def deposit_cash(account_no, amount) when is_binary(account_no) and amount > 0 do
    case bank() |> Bank.deposit_cash(account_no, amount) do
      {:ok, bank} -> Agent.update(__MODULE__, fn x -> %{x | bank: bank} end)
      err -> err
    end
  end

  def transfer(from_owner, to_owner, amount)
      when is_pid(from_owner) and is_pid(to_owner) and amount > 0 do
    with {:ok, from_no} <- get_account_no(from_owner),
         {:ok, to_no} <- get_account_no(to_owner) do
      transfer(from_no, to_no, amount)
    else
      err -> err
    end
  end

  def transfer(from_no, to_no, amount)
      when is_binary(from_no) and is_binary(to_no) and amount > 0 do
    case Bank.transfer(bank(), from_no, to_no, amount) do
      {:ok, bank} -> Agent.update(__MODULE__, fn x -> %{x | bank: bank} end)
    end
  end
end

defmodule BankAgent do
  use Agent

  defmodule State do
    defstruct [
      :bank,
      # account_registry - owner => account_no
      account_registry: %{},
      # owner_registry - account_no => owner
      owner_registry: %{}
    ]
  end

  def start_link(args) do
    case Bank.init_customer_bank_ledgers(%Bank{}) do
      {:ok, bank} -> Agent.start_link(fn -> struct(State, [bank: bank] ++ args) end)
      err -> err
    end
  end

  def stop(agent), do: Agent.stop(agent)

  def state(agent), do: Agent.get(agent, & &1)
  def bank(agent), do: state(agent).bank
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
      {:ok, account} -> account.deposit
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

  def transfer(agent, from_owner, to_owner, amount)
      when is_pid(from_owner) and is_pid(to_owner) and amount > 0 do
    with {:ok, from_no} <- get_account_no(agent, from_owner),
         {:ok, to_no} <- get_account_no(agent, to_owner) do
      transfer(agent, from_no, to_no, amount)
    else
      err -> err
    end
  end

  def transfer(agent, from_no, to_no, amount)
      when is_binary(from_no) and is_binary(to_no) and amount > 0 do
    case Bank.transfer(bank(agent), from_no, to_no, amount) do
      {:ok, bank} -> Agent.update(agent, fn x -> %{x | bank: bank} end)
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
end

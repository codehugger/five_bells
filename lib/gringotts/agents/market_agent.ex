defmodule MarketAgent do
  use Agent

  defmodule State do
    defstruct [
      :name,
      :bank,
      :account_no,
      initial_deposit: 0,
      products_sold: 0,
      current_cycle: 0,
      inventory_count: 0,
      max_inventory: 0
    ]
  end

  def start_link(bank \\ BankAgent, args \\ [])

  def start_link(bank, args) when is_atom(bank) and is_list(args) do
    start_link(Process.whereis(bank), args)
  end

  def start_link(bank, args) when is_pid(bank) and is_list(args) do
    case Agent.start_link(fn -> struct(State, [name: __MODULE__, bank: bank] ++ args) end,
           name: __MODULE__
         ) do
      {:ok, market} = resp ->
        case open_deposit_account(market) do
          :ok -> resp
          err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  def state(), do: Agent.get(__MODULE__, & &1)
  def name(), do: state().name
  def bank(), do: state().bank
  def current_cycle(), do: state().current_cycle
  def products_sold(), do: state().products_sold
  def inventory_count(), do: state().inventory_count
  def initial_deposit(), do: state().initial_deposit

  def reset_cycle(cycle) do
    adjust_prices(cycle)

    IO.puts("Restocking inventory...")

    Agent.update(__MODULE__, fn x ->
      %{x | products_sold: 0, current_cycle: cycle, inventory_count: x.max_inventory}
    end)
  end

  def purchase(customer) when is_pid(customer) do
    case out_of_stock?() do
      true ->
        {:error, :out_of_stock}

      false ->
        case BankAgent.transfer(customer, Process.whereis(MarketAgent), 1) do
          :ok ->
            product = %Product{}
            sold = products_sold() + 1

            IO.puts(
              "Selling #{inspect(product)} to #{inspect(customer)} -> (#{sold} products sold so far)"
            )

            Agent.update(__MODULE__, fn x ->
              %{x | products_sold: sold, inventory_count: x.inventory_count - 1}
            end)

            {:ok, product}

          err ->
            err
        end
    end
  end

  def out_of_stock?() do
    case state().inventory_count <= 0 do
      true ->
        IO.puts("OUT OF STOCK!!!")
        true

      false ->
        false
    end
  end

  #############################################################################
  # Private
  #############################################################################

  defp adjust_prices(_cycle) do
    IO.puts("Adjusting prices...")
  end

  defp open_deposit_account(market) do
    cond do
      bank() != nil ->
        case BankAgent.open_deposit_account(market, initial_deposit()) do
          {:ok, account_no} -> Agent.update(market, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end
end

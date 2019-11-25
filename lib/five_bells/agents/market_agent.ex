defmodule MarketAgent do
  use Agent

  defmodule State do
    defstruct [
      :name,
      :bank,
      :account_no,
      :supplier,
      initial_deposit: 0,
      products_sold: 0,
      products_sold_total: 0,
      current_cycle: 0,
      max_inventory: -1,
      inventory: []
    ]
  end

  def start_link(args) do
    case Agent.start_link(fn -> struct(State, args) end) do
      {:ok, agent} = resp ->
        case open_deposit_account(agent) do
          :ok -> resp
          err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  def state(agent), do: Agent.get(agent, & &1)
  def name(agent), do: state(agent).name
  def bank(agent), do: state(agent).bank
  def supplier(agent), do: state(agent).supplier
  def inventory(agent), do: state(agent).inventory
  def current_cycle(agent), do: state(agent).current_cycle
  def products_sold(agent), do: state(agent).products_sold
  def inventory_count(agent), do: length(inventory(agent))
  def max_inventory(agent), do: state(agent).max_inventory
  def initial_deposit(agent), do: state(agent).initial_deposit
  def out_of_stock?(agent), do: length(inventory(agent)) <= 0
  def uses_inventory?(agent), do: max_inventory(agent) > 0
  def full?(agent), do: remaining_space(agent) <= 0
  def remaining_space(agent), do: max_inventory(agent) - inventory_count(agent)
  def quantity_available?(agent, quantity), do: inventory_count(agent) - quantity >= 0
  def discard_inventory?(agent), do: !uses_inventory?(agent)

  def set_supplier(agent, supplier) when is_pid(supplier) do
    Agent.update(agent, fn x -> %{x | supplier: supplier} end)
  end

  def set_bank(agent, bank) when is_pid(bank) do
    Agent.update(agent, fn x -> %{x | bank: bank} end)
  end

  def needs_to_restock?(agent) do
    out_of_stock?(agent) && max_inventory(agent) - inventory_count(agent) > 0
  end

  def reset_cycle(agent, cycle) do
    adjust_prices(cycle)

    # discard the inventory if required to do so
    inventory = if discard_inventory?(agent), do: [], else: inventory(agent)

    Agent.update(agent, fn x ->
      %{
        x
        | products_sold: 0,
          products_sold_total: x.products_sold_total + x.products_sold,
          current_cycle: cycle,
          inventory: inventory
      }
    end)
  end

  def sell_to_customer(agent, customer, quantity \\ 1) when is_pid(customer) do
    with :ok <- acquire_stock(agent, quantity),
         {:ok, _product} = result <- sell_products(agent, customer, quantity) do
      result
    else
      err -> err
    end
  end

  def price_to_customer(_agent), do: 1

  def acquire_stock(agent, quantity) do
    case supplier(agent) do
      nil ->
        {:error, :no_supplier}

      supplier ->
        case needs_to_restock?(agent) || uses_inventory?(agent) == false do
          true ->
            with {:ok, products} <- FactoryAgent.sell_to_customer(supplier, agent, quantity),
                 :ok <- add_to_inventory(agent, products) do
              :ok
            else
              err -> err
            end

          false ->
            :ok
        end
    end
  end

  #############################################################################
  # Private
  #############################################################################

  defp sell_products(agent, customer, quantity) do
    case quantity_available?(agent, quantity) do
      false ->
        {:error, {:not_enough_stock, [available: inventory_count(agent), requested: quantity]}}

      true ->
        case BankAgent.transfer(bank(agent), customer, agent, quantity) do
          :ok ->
            case remove_from_inventory(agent, quantity) do
              {:ok, products} = result ->
                Agent.update(agent, fn x ->
                  %{x | products_sold: x.products_sold + length(products)}
                end)

                result

              err ->
                err
            end

          err ->
            err
        end
    end
  end

  defp remove_from_inventory(agent, quantity) do
    case length(inventory(agent)) >= quantity do
      true ->
        {outgoing, remaining} = Enum.split(inventory(agent), quantity)
        {Agent.update(agent, fn x -> %{x | inventory: remaining} end), outgoing}

      false ->
        {:error, :out_of_stock}
    end
  end

  defp add_to_inventory(agent, products) do
    case remaining_space(agent) >= length(products) || uses_inventory?(agent) == false do
      false -> {:error, :not_enough_space}
      true -> Agent.update(agent, fn x -> %{x | inventory: x.inventory ++ products} end)
    end
  end

  defp adjust_prices(_cycle) do
    IO.puts("Adjusting prices...")
  end

  defp open_deposit_account(agent) do
    cond do
      bank(agent) != nil ->
        case BankAgent.open_deposit_account(bank(agent), agent, initial_deposit(agent)) do
          {:ok, account_no} -> Agent.update(agent, fn x -> %{x | account_no: account_no} end)
          {:error, _} = err -> err
        end

      true ->
        {:error, :no_bank_assigned}
    end
  end
end

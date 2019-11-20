defmodule MarketAgent do
  use Agent

  def start_link do
    Agent.start_link(
      fn -> %{name: __MODULE__, products_sold: 0, current_cycle: 0, inventory_count: 20} end,
      name: __MODULE__
    )
  end

  def state do
    Agent.get(__MODULE__, & &1)
  end

  def products_sold, do: Agent.get(__MODULE__, & &1.products_sold)

  def reset_cycle(cycle) do
    adjust_prices(cycle)

    IO.puts("Restocking inventory...")

    Agent.update(__MODULE__, fn x ->
      %{x | products_sold: 0, current_cycle: cycle, inventory_count: 10}
    end)
  end

  def adjust_prices(_cycle) do
    IO.puts("Adjusting prices...")
  end

  def purchase(customer) when is_pid(customer) do
    case out_of_stock?() do
      true ->
        {:error, :out_of_stock}

      false ->
        product = %Product{}
        sold = products_sold() + 1

        IO.puts(
          "Selling #{inspect(product)} to #{inspect(customer)} -> (#{sold} products sold so far)"
        )

        Agent.update(__MODULE__, fn x ->
          %{x | products_sold: sold, inventory_count: x.inventory_count - 1}
        end)

        {:ok, product}
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
end

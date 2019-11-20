defmodule FactoryAgent do
  use Agent

  defmodule State do
    defstruct [
      :product_name,
      :sell_price,
      :output,
      :market,
      :employees,
      :supplier,
      name: "Factory"
    ]
  end

  def start_link(name, product_name, market, supplier \\ nil) do
    Agent.start_link(fn ->
      %State{name: name, product_name: product_name, market: market, supplier: supplier}
    end)
  end

  def stop(agent), do: Agent.stop(agent)
end

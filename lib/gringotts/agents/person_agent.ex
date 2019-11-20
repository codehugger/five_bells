defmodule PersonAgent do
  use Agent

  def start_link(name) do
    Agent.start_link(fn -> %{name: name, consumed: []} end)
  end

  def consume(person, product) do
    # IO.puts("Consumed #{inspect(product)}")
    Agent.update(person, fn x -> %{x | consumed: [product | x[:consumed]]} end)
  end

  def purchase(person) do
    case MarketAgent.purchase(person) do
      {:ok, _} = resp ->
        # IO.puts("Bought #{inspect(product)}")
        resp

      {:error, _} = err ->
        err
    end
  end

  def evaluate(person, _cycle) do
    case purchase(person) do
      {:ok, product} ->
        consume(person, product)

      {:error, _} = err ->
        err
    end
  end
end

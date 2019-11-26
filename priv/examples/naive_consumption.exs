# Banks and companies
{:ok, simulation} = SimulationAgent.start_link(simulation_id: "naive_consumption")
{:ok, bank} = BankAgent.start_link([])
{:ok, factory} = FactoryAgent.start_link(bank: bank, initial_deposit: 0)
{:ok, market} = MarketAgent.start_link(bank: bank, supplier: factory, initial_deposit: 1)

# People
people =
  Enum.map(1..5, fn x ->
    {:ok, person} =
      PersonAgent.start_link(name: "Person#{x}", bank: bank, market: market, initial_deposit: 10)

    person
  end)

# Sanity tests
# IO.inspect(BankAgent.state())
# IO.inspect(MarketAgent.state(market))
# IO.inspect(FactoryAgent.state(factory))
# IO.inspect(FactoryAgent.produce(factory))
# IO.inspect(MarketAgent.sell_to_customer(market, person))
# IO.inspect(:sys.get_state(market))
# IO.inspect(:sys.get_state(bank))

# Simulation

# [person | _] = people
# PersonAgent.evaluate(person, 1)

Enum.each(1..10, fn _ ->
  SimulationAgent.evaluate(simulation, fn cycle, simulation_id ->
    people
    |> Enum.shuffle()
    |> Enum.each(fn person ->
      case PersonAgent.evaluate(person, cycle) do
        {:error, _} -> false
        _ -> true
      end
    end)

    MarketAgent.evaluate(market, cycle)
    FactoryAgent.evaluate(factory, cycle)
    BankAgent.evaluate(bank, cycle, simulation_id)
  end)
end)

IO.puts("")
IO.puts("################################################################################")
IO.puts("SUMMARY")
IO.puts("################################################################################")
IO.puts("")
IO.puts("--------------------------------------------------------------------------------")
IO.puts("BANKS")
IO.puts("--------------------------------------------------------------------------------")
IO.puts("")
IO.inspect(:sys.get_state(bank))
IO.puts("")

IO.puts("--------------------------------------------------------------------------------")
IO.puts("FACTORIES")
IO.puts("--------------------------------------------------------------------------------")
IO.puts("")
IO.inspect(:sys.get_state(factory))
IO.inspect(BankAgent.get_account(bank, factory))
IO.puts("")

IO.puts("--------------------------------------------------------------------------------")
IO.puts("MARKETS")
IO.puts("--------------------------------------------------------------------------------")
IO.puts("")
IO.inspect(:sys.get_state(market))
IO.inspect(BankAgent.get_account(bank, market))
IO.puts("")

IO.puts("--------------------------------------------------------------------------------")
IO.puts("PEOPLE")
IO.puts("--------------------------------------------------------------------------------")
IO.puts("")

Enum.each(people, fn x ->
  IO.inspect(:sys.get_state(x))
  IO.inspect(BankAgent.get_account(bank, x))
end)

IO.puts("")

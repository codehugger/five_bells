# Agents

{:ok, _} = MarketAgent.start_link
people = Enum.map(1..100, fn x ->
  {:ok, person} = PersonAgent.start_link("Person#{x}")
  person
end)

# Simulation

# IO.inspect(market_agent)
# IO.inspect(people)

Enum.each(1..100, fn cycle ->
  people
  |> Enum.shuffle()
  |> Enum.each(fn person ->
    IO.inspect(:sys.get_state(person).name)
    PersonAgent.evaluate(person, cycle)
  end)
  MarketAgent.reset_cycle(cycle)
end)

IO.inspect(length(:sys.get_state(List.first(people)).consumed))
IO.inspect(:sys.get_state(List.first(people)).name)

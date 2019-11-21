# Agents

{:ok, bank} = BankAgent.start_link
{:ok, market} = MarketAgent.start_link(bank, max_inventory: 10)
people = Enum.map(1..20, fn x ->
  {:ok, person} = PersonAgent.start_link("Person#{x}", bank, market, initial_deposit: 10)
  person
end)

# Simulation

Enum.each(1..50, fn cycle ->
  people
  |> Enum.shuffle()
  |> Enum.each(fn person ->
    case PersonAgent.evaluate(person, cycle) do
      {:error, _} -> false
      _ -> true
    end
  end)
  MarketAgent.reset_cycle(cycle)
end)

IO.inspect(BankAgent.bank)

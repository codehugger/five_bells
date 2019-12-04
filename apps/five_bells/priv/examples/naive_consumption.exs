import Ecto.Query, only: [from: 2]

alias FiveBells.Agents.{BankAgent, MarketAgent, FactoryAgent, PersonAgent, SimulationAgent}

# Banks and companies
{:ok, simulation} = SimulationAgent.start_link(simulation_id: "naive_consumption")
{:ok, bank} = BankAgent.start_link([])

{:ok, factory} =
  FactoryAgent.start_link(
    bank: bank,
    initial_deposit: 100,
    output: 10,
    max_inventory: 100,
    initiate_sale: true
  )

{:ok, market} =
  MarketAgent.start_link(bank: bank, supplier: factory, initial_deposit: 50, max_inventory: 20)

:ok = FactoryAgent.set_market(factory, market)

# People
people =
  Enum.map(1..40, fn x ->
    {:ok, person} =
      PersonAgent.start_link(name: "Person#{x}", bank: bank, market: market, initial_deposit: 20)

    person
  end)

# clear simulation data before starting
from(t in FiveBells.Statistics.TimeSeries, where: t.simulation_id == "naive_consumption")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Transaction, where: t.simulation_id == "naive_consumption")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Deposit, where: t.simulation_id == "naive_consumption")
|> FiveBells.Repo.delete_all()

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

Enum.each(1..30, fn _ ->
  SimulationAgent.evaluate(simulation, fn cycle, simulation_id ->
    people
    |> Enum.shuffle()
    |> Enum.each(fn person ->
      case PersonAgent.evaluate(person, cycle, simulation_id) do
        {:error, _} -> false
        _ -> true
      end
    end)

    # market and factory communication happens at the end of the day (restocking)
    FactoryAgent.evaluate(factory, cycle, simulation_id)
    MarketAgent.evaluate(market, cycle, simulation_id)

    BankAgent.evaluate(bank, cycle, simulation_id)
  end)
end)

# IO.puts("")
# IO.puts("################################################################################")
# IO.puts("SUMMARY")
# IO.puts("################################################################################")
# IO.puts("")
# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("BANKS")
# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("")
# IO.inspect(:sys.get_state(bank))
# IO.puts("")

# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("FACTORIES")
# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("")
# IO.inspect(:sys.get_state(factory))
# IO.inspect(BankAgent.get_account(bank, factory))
# IO.puts("")

# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("MARKETS")
# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("")
# IO.inspect(:sys.get_state(market))
# IO.inspect(BankAgent.get_account(bank, market))
# IO.puts("")

# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("PEOPLE")
# IO.puts("--------------------------------------------------------------------------------")
# IO.puts("")

# Enum.each(people, fn x ->
#   IO.inspect(:sys.get_state(x))
#   IO.inspect(BankAgent.get_account(bank, x))
# end)

# IO.puts("")

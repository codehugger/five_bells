import Ecto.Query

alias FiveBells.Agents.{BankAgent, FactoryAgent, MarketAgent, PersonAgent, SimulationAgent}

###############################################################################
# Clear the simulation data
###############################################################################

from(t in FiveBells.Statistics.TimeSeries, where: t.simulation_id == "keiretsu")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Transaction, where: t.simulation_id == "keiretsu")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Deposit, where: t.simulation_id == "keiretsu")
|> FiveBells.Repo.delete_all()

###############################################################################
# Bank
###############################################################################

{:ok, bank} = BankAgent.start_link(bank_no: "B-0001")

###############################################################################
# Competing Component Factories selling -> Glass through Market 1
###############################################################################

{:ok, glass_market} =
  MarketAgent.start_link(
    bank: bank,
    market_no: "M-GLASS",
    # suppliers: [glass_factory_1, glass_factory_2],
    initial_deposit: 100,
    max_inventory: 15,
    min_spread: 1,
    max_spread: 1,
    spread: 1,
    bid_price: 5,
    sell_price: 10
  )

{:ok, glass_factory_1} =
  FactoryAgent.start_link(
    bank: bank,
    factory_no: "F-GLASS-1",
    initial_deposit: 100,
    output: 15,
    max_inventory: 30,
    market: glass_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "GLASS"}
  )

# {:ok, glass_factory_2} =
#   FactoryAgent.start_link(
#     bank: bank,
#     factory_no: "F-GLASS-2",
#     initial_deposit: 100,
#     output: 10,
#     max_inventory: 30,
#     market: glass_market,
#     initiate_sale: true,
#     recipe: %Recipe{components: [], product_name: "GLASS"}
#   )

###############################################################################
# Competing Component Factories selling -> Steel through Market 1
###############################################################################

{:ok, metal_market} =
  MarketAgent.start_link(
    market_no: "M-METAL",
    bank: bank,
    # suppliers: [metal_factory_1, metal_factory_2],
    initial_deposit: 100,
    max_inventory: 15,
    min_spread: 1,
    max_spread: 1,
    spread: 1,
    bid_price: 5,
    sell_price: 10
  )

{:ok, metal_factory_1} =
  FactoryAgent.start_link(
    bank: bank,
    factory_no: "F-METAL-1",
    initial_deposit: 100,
    output: 15,
    max_inventory: 15,
    market: metal_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "METAL"}
  )

# {:ok, metal_factory_2} =
#   FactoryAgent.start_link(
#     bank: bank,
#     factory_no: "F-METAL-2",
#     initial_deposit: 100,
#     output: 5,
#     max_inventory: 20,
#     market: metal_market,
#     initiate_sale: true,
#     recipe: %Recipe{components: [], product_name: "METAL"}
#   )

###############################################################################
# End-product assembler factory
###############################################################################

{:ok, end_product_market} =
  MarketAgent.start_link(
    bank: bank,
    market_no: "M-ELECTRONIC",
    # supplier: end_product_factory,
    initial_deposit: 1000,
    max_inventory: 15,
    min_spread: 1,
    max_spread: 5,
    spread: 2,
    bid_price: 5,
    sell_price: 10
  )

{:ok, end_product_factory} =
  FactoryAgent.start_link(
    bank: bank,
    factory_no: "F-ELECTRONIC",
    initial_deposit: 1000,
    output: 15,
    max_inventory: 15,
    initiate_sale: true,
    recipe: %Recipe{components: ["GLASS", "METAL"], product_name: "ELECTRONIC"},
    suppliers: %{"GLASS" => glass_market, "METAL" => metal_market},
    market: end_product_market
  )

###############################################################################
# Customers
###############################################################################

customers =
  Enum.map(1..10, fn x ->
    {:ok, customer} =
      PersonAgent.start_link(
        name: "Customer",
        person_no: "P-#{String.pad_leading("#{x}", 4, "0")}",
        bank: bank,
        market: end_product_market,
        initial_deposit: 200
      )

    customer
  end)

###############################################################################
# Simulation
###############################################################################

{:ok, simulation} = SimulationAgent.start_link(simulation_id: "keiretsu")

factories = [
  glass_factory_1,
  # glass_factory_2,
  metal_factory_1,
  # metal_factory_2,
  end_product_factory
]

markets = [metal_market, glass_market, end_product_market]

###############################################################################
# Evaluate
###############################################################################

cycles = 30

# IO.inspect(:sys.get_state(end_product_factory))
# IO.inspect(:sys.get_state(end_product_market))

Enum.each(1..cycles, fn _ ->
  SimulationAgent.evaluate(simulation, fn cycle, simulation_id ->
    # customers start each round by going to the store/retailer
    customers
    |> Enum.shuffle()
    |> Enum.each(fn person ->
      case PersonAgent.evaluate(person, cycle, simulation_id) do
        {:error, _} -> false
        _ -> true
      end
    end)

    # market and factory communication happens at the end of the day (restocking)
    factories
    |> Enum.shuffle()
    |> Enum.each(fn factory ->
      case(FactoryAgent.evaluate(factory, cycle, simulation_id)) do
        {:error, _} -> false
        _ -> true
      end
    end)

    markets
    |> Enum.shuffle()
    |> Enum.each(fn market ->
      case(MarketAgent.evaluate(market, cycle, simulation_id)) do
        {:error, _} -> false
        _ -> true
      end
    end)

    # bank audit happens at the very end
    BankAgent.evaluate(bank, cycle, simulation_id)
  end)
end)

import Ecto.Query

alias FiveBells.Agents.{BankAgent, FactoryAgent, MarketAgent, PersonAgent, SimulationAgent}

###############################################################################
# Clear the simulation data
###############################################################################

from(t in FiveBells.Statistics.TimeSeries, where: t.simulation_id == "arms_length")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Transaction, where: t.simulation_id == "arms_length")
|> FiveBells.Repo.delete_all()

from(t in FiveBells.Banks.Deposit, where: t.simulation_id == "arms_length")
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
    entity_no: "M-GLASS",
    # suppliers: [glass_factory_1, glass_factory_2],
    initial_deposit: 100,
    max_inventory: 5
  )

{:ok, glass_factory_1} =
  FactoryAgent.start_link(
    bank: bank,
    entity_no: "F-GLASS-1",
    initial_deposit: 100,
    output: 5,
    max_inventory: 5,
    market: glass_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "GLASS"}
  )

{:ok, glass_factory_2} =
  FactoryAgent.start_link(
    bank: bank,
    entity_no: "F-GLASS-2",
    initial_deposit: 100,
    output: 5,
    max_inventory: 5,
    market: glass_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "GLASS"}
  )

###############################################################################
# Competing Component Factories selling -> Steel through Market 1
###############################################################################

{:ok, metal_market} =
  MarketAgent.start_link(
    entity_no: "M-METAL",
    bank: bank,
    # suppliers: [metal_factory_1, metal_factory_2],
    initial_deposit: 100,
    max_inventory: 5
  )

{:ok, metal_factory_1} =
  FactoryAgent.start_link(
    bank: bank,
    entity_no: "F-METAL-1",
    initial_deposit: 100,
    output: 5,
    max_inventory: 5,
    market: metal_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "METAL"}
  )

{:ok, metal_factory_2} =
  FactoryAgent.start_link(
    bank: bank,
    entity_no: "F-METAL-2",
    initial_deposit: 100,
    output: 5,
    max_inventory: 5,
    market: metal_market,
    initiate_sale: true,
    recipe: %Recipe{components: [], product_name: "METAL"}
  )

###############################################################################
# End-product assembler factory
###############################################################################

{:ok, end_product_market} =
  MarketAgent.start_link(
    bank: bank,
    entity_no: "M-ELECTRONIC",
    # supplier: end_product_factory,
    initial_deposit: 1000,
    max_inventory: 5,
    min_spread: 2,
    max_spread: 3,
    spread: 2,
    bid_price: 5,
    sell_price: 10
  )

{:ok, end_product_factory} =
  FactoryAgent.start_link(
    bank: bank,
    entity_no: "F-ELECTRONIC",
    initial_deposit: 1000,
    output: 5,
    max_inventory: 5,
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
        entity_no: "P-#{String.pad_leading("#{x}", 4, "0")}",
        bank: bank,
        market: end_product_market,
        initial_deposit: 50
      )

    customer
  end)

###############################################################################
# Simulation
###############################################################################

{:ok, simulation} = SimulationAgent.start_link(simulation_id: "arms_length")

factories = [
  glass_factory_1,
  glass_factory_2,
  metal_factory_1,
  metal_factory_2,
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

    # customers start each round by going to the store/retailer
    customers
    |> Enum.shuffle()
    |> Enum.each(fn person ->
      case PersonAgent.evaluate(person, cycle, simulation_id) do
        {:error, _} -> false
        _ -> true
      end
    end)

    # bank audit happens at the very end
    BankAgent.evaluate(bank, cycle, simulation_id)
  end)
end)

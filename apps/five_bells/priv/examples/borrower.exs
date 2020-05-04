import Ecto.Query, only: [from: 2]
require Logger

alias FiveBells.Agents.{SimulationAgent, BorrowerAgent, BankAgent}

simulation_id = "borrower"

# clear simulation data before starting
defmodule BorrowerSimulation do
  def clear_simulation(simulation_id) do
    from(t in FiveBells.Statistics.TimeSeries, where: t.simulation_id == ^simulation_id)
    |> FiveBells.Repo.delete_all()

    from(t in FiveBells.Banks.Transaction, where: t.simulation_id == ^simulation_id)
    |> FiveBells.Repo.delete_all()

    from(t in FiveBells.Banks.Deposit, where: t.simulation_id == ^simulation_id)
    |> FiveBells.Repo.delete_all()
  end
end

# Borrower simulation

BorrowerSimulation.clear_simulation("borrower")

{:ok, simulation} = SimulationAgent.start_link(simulation_id: simulation_id)
{:ok, bank} = BankAgent.start_link()

borrowers =
  Enum.map(1..10, fn x ->
    case BorrowerAgent.start_link(
           person_no: "R-#{String.pad_leading("#{x}", 4, ["0"])}",
           bank: bank,
           loan_amount: 1200,
           interest_rate: 10.0,
           loan_duration: 12
         ) do
      {:ok, borrower} -> borrower
      err -> err
    end
  end)

Enum.each(1..120, fn _ ->
  SimulationAgent.evaluate(simulation, fn cycle, simulation_id ->
    Logger.log(:info, "Running cycle: #{cycle}")

    BankAgent.evaluate(bank, cycle, simulation_id)

    Enum.each(borrowers, fn b ->
      BorrowerAgent.evaluate(b, cycle, simulation_id)
    end)

    # indicate that the round went ok
    :ok
  end)
end)

IO.puts("Simulation finished!")
# IO.puts(SimulationAgent.simulation_id(simulation))

# IO.inspect(:sys.get_state(bank))

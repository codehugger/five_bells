defmodule FiveBellsWeb.BankController do
  use FiveBellsWeb, :controller

  import Ecto.Query

  alias FiveBells.Statistics.TimeSeries
  alias FiveBells.Banks.Transaction
  alias FiveBells.Banks.Deposit

  def show(conn, %{
        "simulation_id" => simulation_id,
        "bank_id" => bank_id
      }) do
    time_series =
      FiveBells.Repo.all(
        from(t in TimeSeries,
          where: t.simulation_id == ^simulation_id and t.entity_id == ^bank_id,
          order_by: t.cycle
        )
      )
      |> Enum.group_by(fn s -> s.label end, fn s -> [s.cycle, s.value] end)

    max_cycle =
      FiveBells.Repo.one(
        from(d in Deposit, select: max(d.cycle), where: d.simulation_id == ^simulation_id)
      )

    accounts =
      FiveBells.Repo.all(
        from(t in Deposit,
          where: t.simulation_id == ^simulation_id and t.cycle == ^max_cycle,
          order_by: [t.owner_type, t.owner_id]
        )
      )

    transactions =
      FiveBells.Repo.all(
        from(t in Transaction,
          where: t.simulation_id == ^simulation_id,
          order_by: t.cycle
        )
      )

    render(conn, "show.html",
      accounts: accounts,
      transactions: transactions,
      time_series: time_series,
      simulation_id: simulation_id,
      bank_id: bank_id
    )
  end
end

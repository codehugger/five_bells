defmodule FiveBellsWeb.SimulationController do
  use FiveBellsWeb, :controller

  import Ecto.Query

  alias FiveBells.Statistics.TimeSeries

  def index(conn, _params) do
    simulations =
      FiveBells.Repo.all(
        from(t in TimeSeries, distinct: t.simulation_id, order_by: t.simulation_id)
      )

    render(conn, "index.html", simulations: simulations)
  end

  def show(conn, %{"id" => id}) do
    entities =
      FiveBells.Repo.all(
        from(t in TimeSeries,
          where: t.simulation_id == ^id,
          distinct: t.entity_id,
          order_by: t.entity_id
        )
      )

    time_series =
      FiveBells.Repo.all(
        from(t in TimeSeries,
          where: t.simulation_id == ^id,
          order_by: t.cycle
        )
      )

    totals =
      FiveBells.Repo.all(
        from(t in FiveBells.Statistics.TimeSeries,
          where:
            t.simulation_id == ^id and t.entity_id == "B-0001" and
              like(t.label, "bank.total%"),
          order_by: t.cycle
        )
      )
      |> Enum.group_by(fn s -> s.label end, fn s -> [s.cycle, s.value] end)

    IO.inspect(totals)

    render(conn, "show.html", entities: entities, time_series: time_series, totals: totals, id: id)
  end
end

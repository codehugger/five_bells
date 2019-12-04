defmodule FiveBellsWeb.EntityController do
  use FiveBellsWeb, :controller

  import Ecto.Query

  alias FiveBells.Statistics.TimeSeries
  alias FiveBells.Banks.Transaction

  def show(conn, %{
        "simulation_id" => simulation_id,
        "entity_id" => entity_id
      }) do
    entity_type =
      FiveBells.Repo.one(
        from(t in TimeSeries,
          where: t.simulation_id == ^simulation_id and t.entity_id == ^entity_id,
          limit: 1
        )
      ).entity_type

    time_series =
      FiveBells.Repo.all(
        from(t in TimeSeries,
          where: t.simulation_id == ^simulation_id and t.entity_id == ^entity_id,
          order_by: t.cycle
        )
      )
      |> Enum.group_by(fn s -> s.label end, fn s -> [s.cycle, s.value] end)

    transactions =
      case entity_type do
        "Bank" ->
          FiveBells.Repo.all(
            from(t in Transaction,
              where: t.simulation_id == ^simulation_id,
              order_by: t.cycle
            )
          )

        _ ->
          []
      end

    render(conn, "show.html",
      transactions: transactions,
      time_series: time_series,
      simulation_id: simulation_id,
      entity_id: entity_id,
      entity_type: entity_type
    )
  end
end

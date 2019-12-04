defmodule FiveBellsWeb.EntityController do
  use FiveBellsWeb, :controller

  import Ecto.Query

  alias FiveBells.Statistics.TimeSeries
  alias FiveBells.Banks.Transaction
  alias FiveBells.Banks.Deposit

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

    deposits =
      case entity_type do
        "Bank" ->
          []

        _ ->
          FiveBells.Repo.all(
            from(t in Deposit,
              where: t.simulation_id == ^simulation_id and t.owner_id == ^entity_id,
              order_by: [desc: t.cycle]
            )
          )
      end

    accounts =
      case entity_type do
        "Bank" ->
          FiveBells.Repo.all(
            from(t in Deposit,
              where: t.simulation_id == ^simulation_id
            )
          )

        _ ->
          []
      end

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
      accounts: accounts,
      deposits: deposits,
      transactions: transactions,
      time_series: time_series,
      simulation_id: simulation_id,
      entity_id: entity_id,
      entity_type: entity_type
    )
  end
end

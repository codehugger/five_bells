import Ecto.Query

simulation_id = "borrower"

series =
  FiveBells.Repo.all(
    from(t in FiveBells.Statistics.TimeSeries,
      where:
        t.simulation_id == ^simulation_id and t.entity_id == "B-0001" and
          like(t.label, "bank.total%"),
      order_by: t.cycle
    )
  )

# IO.inspect(Enum.group_by(series, fn s -> s.label end, fn s -> [s.cycle, s.value] end))

# labelled_series =
#   Enum.group_by(
#     Enum.map(series, fn x -> [cycle: x.cycle, label: x.label, key: x.key, value: x.value] end),
#     fn x -> x[:label] end
#   )

# keyed_series =
#   Enum.map(labelled_series, fn {label, series} ->
#     [label, Enum.group_by(series, fn s -> s[:key] end)]
#   end)

# # Enum.map(series, fn s -> [s[:cycle], s[:value]] end

# IO.inspect(keyed_series)

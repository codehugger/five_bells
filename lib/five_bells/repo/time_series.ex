defmodule Repo.TimeSeries do
  use Ecto.Schema

  schema "time_series" do
    field(:label, :string)
    field(:key, :string)
    field(:entity_type, :string)
    field(:entity_id, :string)
    field(:value, :integer)
    field(:cycle, :integer)
    field(:simulation_id, :string)
  end
end

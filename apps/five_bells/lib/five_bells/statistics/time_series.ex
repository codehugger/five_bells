defmodule FiveBells.Statistics.TimeSeries do
  use Ecto.Schema
  import Ecto.Changeset

  schema "time_series" do
    field :cycle, :integer
    field :entity_id, :string
    field :entity_type, :string
    field :key, :string
    field :label, :string
    field :simulation_id, :string
    field :value, :integer

    timestamps()
  end

  @doc false
  def changeset(time_series, attrs) do
    time_series
    |> cast(attrs, [:label, :key, :entity_type, :entity_id, :value, :cycle, :simulation_id])
    |> validate_required([:label, :key, :entity_type, :entity_id, :value, :cycle, :simulation_id])
  end
end

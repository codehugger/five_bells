defmodule Repo.TimeSeries do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field(:cycle, :integer)
    field(:label, :integer)
    field(:value, :string)
    field(:simulation_id, :string)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:cycle, :label, :value, :simulation_id])
    |> validate_required([:cycle, :label, :value, :simulation_id])
  end
end

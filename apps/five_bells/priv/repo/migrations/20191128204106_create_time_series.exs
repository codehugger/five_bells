defmodule FiveBells.Repo.Migrations.CreateTimeSeries do
  use Ecto.Migration

  def change do
    create table(:time_series) do
      add(:label, :string)
      add(:key, :string)
      add(:entity_type, :string)
      add(:entity_id, :string)
      add(:value, :integer)
      add(:cycle, :integer)
      add(:simulation_id, :string)

      timestamps(default: fragment("NOW()"))
    end
  end
end

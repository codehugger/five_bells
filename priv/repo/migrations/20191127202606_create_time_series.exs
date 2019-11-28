defmodule FiveBells.Repo.Migrations.CreateTimeSeries do
  use Ecto.Migration

  def change do
    create table(:time_series) do
      add(:key, :string)
      add(:label, :string)
      add(:entity_id, :string)
      add(:entity_type, :string)
      add(:value, :integer)
      add(:cycle, :integer)
      add(:simulation_id, :string)
    end
  end
end

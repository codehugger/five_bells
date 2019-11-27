defmodule FiveBells.Repo.Migrations.CreateTimeSeries do
  use Ecto.Migration

  def change do
    create table(:time_series) do
      add(:label, :string)
      add(:value, :integer)
      add(:cycle, :integer)
      add(:simulation_id, :string)
    end
  end
end

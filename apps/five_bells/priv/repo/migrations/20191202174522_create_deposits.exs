defmodule FiveBells.Repo.Migrations.CreateDeposits do
  use Ecto.Migration

  def change do
    create table(:deposits) do
      add(:bank_no, :string)
      add(:account_no, :string)
      add(:owner_type, :string)
      add(:owner_id, :string)
      add(:deposit, :integer)
      add(:delta, :integer)
      add(:cycle, :integer)
      add(:simulation_id, :string)

      timestamps(default: fragment("NOW()"))
    end
  end
end

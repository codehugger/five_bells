defmodule FiveBells.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:bank_no, :string)
      add(:deb_no, :string)
      add(:cred_no, :string)
      add(:amount, :integer)
      add(:text, :string)
      add(:cycle, :integer)
      add(:simulation_id, :string)

      timestamps(default: fragment("NOW()"))
    end
  end
end

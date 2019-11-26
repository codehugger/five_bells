defmodule FiveBells.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:bank, :string)
      add(:cycle, :integer)
      add(:deb_no, :string)
      add(:cred_no, :string)
      add(:amount, :integer)
      add(:text, :string)
      add(:simulation_id, :string)
    end
  end
end

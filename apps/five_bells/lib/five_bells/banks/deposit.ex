defmodule FiveBells.Banks.Deposit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "deposits" do
    field(:bank, :string)
    field(:account_no, :string)
    field(:owner_type, :string)
    field(:owner_id, :string)
    field(:deposit, :integer)
    field(:delta, :integer)
    field(:cycle, :integer)
    field(:simulation_id, :string)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:bank, :account_no, :deposit, :delta, :cycle, :simulation_id])
    |> validate_required([:bank, :account_no, :deposit, :delta, :cycle, :simulation_id])
  end
end

defmodule FiveBells.Banks.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :amount, :integer
    field :bank, :string
    field :cred_no, :string
    field :cycle, :integer
    field :deb_no, :string
    field :simulation_id, :string
    field :text, :string

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:deb_no, :cred_no, :amount, :text, :cycle, :bank, :simulation_id])
    |> validate_required([:deb_no, :cred_no, :amount, :text, :cycle, :bank, :simulation_id])
  end
end

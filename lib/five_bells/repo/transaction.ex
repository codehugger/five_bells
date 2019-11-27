defmodule Repo.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field(:amount, :integer)
    field(:cred_no, :string)
    field(:deb_no, :string)
    field(:text, :string)
    field(:cycle, :integer)
    field(:bank, :string)
    field(:simulation_id, :string)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:deb_no, :cred_no, :amount, :text, :cycle, :simulation_id])
    |> validate_required([:deb_no, :cred_no, :amount, :text, :cycle, :simulation_id])
  end
end

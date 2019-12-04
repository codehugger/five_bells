defmodule FiveBells.Banks.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field(:amount, :integer)
    field(:bank_no, :string)
    field(:deb_no, :string)
    field(:deb_owner_type, :string)
    field(:deb_owner_id, :string)
    field(:cred_no, :string)
    field(:cred_owner_type, :string)
    field(:cred_owner_id, :string)
    field(:cycle, :integer)
    field(:simulation_id, :string)
    field(:text, :string)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :deb_no,
      :dep_owner_type,
      :dep_owner_id,
      :cred_no,
      :cred_owner_type,
      :cred_owner_id,
      :amount,
      :text,
      :cycle,
      :bank_no,
      :simulation_id
    ])
    |> validate_required([
      :deb_no,
      :dep_owner_type,
      :dep_owner_id,
      :cred_no,
      :cred_owner_type,
      :cred_owner_id,
      :amount,
      :text,
      :cycle,
      :bank_no,
      :simulation_id
    ])
  end
end

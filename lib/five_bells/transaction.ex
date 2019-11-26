defmodule Transaction do
  use Ecto.Schema

  schema "transactions" do
    field(:cycle, :integer)
    field(:bank, :string)
    field(:deb_no, :string)
    field(:cred_no, :string)
    field(:amount, :integer)
    field(:text, :string)
    field(:simulation_id, :string)
  end

  def changeset(transaction, params \\ %{}) do
    transaction
    |> Ecto.Changeset.cast(params, [
      :cycle,
      :bank,
      :deb_no,
      :cred_no,
      :amount,
      :text,
      :simulation_id
    ])
  end

  @schema_meta_fields [:__meta__]

  def to_storeable_map(struct) do
    association_fields = struct.__struct__.__schema__(:associations)
    waste_fields = association_fields ++ @schema_meta_fields

    struct |> Map.from_struct() |> Map.drop(waste_fields)
  end
end

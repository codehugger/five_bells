defmodule Repo.Transaction do
  use Ecto.Schema

  schema "transactions" do
    field(:amount, :integer)
    field(:cred_no, :string)
    field(:deb_no, :string)
    field(:text, :string)
    field(:cycle, :integer)
    field(:bank, :string)
    field(:simulation_id, :string)
  end
end

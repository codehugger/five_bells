defmodule RepoAgent do
  use Agent

  defmodule State do
    defstruct [:name]
  end

  # We use a singleton repo agent for now (can be easily split into one per table dumped)
  def start_link(args \\ []) do
    Agent.start_link(fn -> struct(State, args) end, name: __MODULE__)
  end

  def flush_data(schema, data \\ []) when is_atom(schema) do
    FiveBells.Repo.insert_all(schema, data)
  end
end

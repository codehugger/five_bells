defmodule FiveBells.Agents.SimulationAgent do
  use Agent

  defmodule State do
    defstruct current_cycle: 1,
              simulation_id: nil
  end

  defp state(agent), do: Agent.get(agent, & &1)

  def start_link(args \\ []) do
    Agent.start_link(fn -> struct(State, args) end)
  end

  # TODO: make the simulation stop on error
  def evaluate(agent, fun \\ fn _cycle, _id -> :ok end) do
    # todo: how to do this?
    case fun.(state(agent).current_cycle, state(agent).simulation_id) do
      :ok ->
        {:ok, Agent.update(agent, fn x -> %{x | current_cycle: x.current_cycle + 1} end)}

      err ->
        err
    end
  end
end

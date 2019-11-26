defmodule SimulationAgent do
  use Agent

  defmodule State do
    defstruct current_cycle: 1,
              simulation_id: nil
  end

  def state(agent), do: Agent.get(agent, & &1)
  def current_cycle(agent), do: state(agent).current_cycle
  def simulation_id(agent), do: state(agent).simulation_id

  def start_link(args \\ []) do
    Agent.start_link(fn -> struct(State, args) end)
  end

  def repo(_agent) do
    {:ok, FiveBells.Repo}
  end

  def evaluate(agent, fun \\ fn _cycle, _id -> :ok end) do
    # todo: how to do this?
    case fun.(current_cycle(agent), simulation_id(agent)) do
      :ok ->
        {:ok, Agent.update(agent, fn x -> %{x | current_cycle: x.current_cycle + 1} end)}

      err ->
        err
    end
  end
end

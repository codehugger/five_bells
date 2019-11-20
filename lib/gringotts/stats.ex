defmodule Stats do
  defstruct values: []

  def add_value(%Stats{} = stat, value) do
    %{stat | values: [value | stat.values]}
  end

  def going_up?(%Stats{values: values}, window_size \\ 2) when length(values) <= window_size do
    Enum.at(values, 0) > Enum.at(values, window_size - 1)
  end

  def going_down?(%Stats{values: values}, window_size \\ 2) when length(values) <= window_size do
    Enum.at(values, 0) > Enum.at(values, window_size - 1)
  end

  def unchanged?(%Stats{values: values}, window_size \\ 2) when length(values) <= window_size do
    Enum.at(values, 0) == Enum.at(values, window_size - 1)
  end
end

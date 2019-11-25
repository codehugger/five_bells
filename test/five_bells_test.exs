defmodule FiveBellsTest do
  use ExUnit.Case
  doctest FiveBells

  test "greets the world" do
    assert FiveBells.hello() == :world
  end
end

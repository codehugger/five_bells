defmodule GringottsTest do
  use ExUnit.Case
  doctest Gringotts

  test "greets the world" do
    assert Gringotts.hello() == :world
  end
end

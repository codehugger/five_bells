defmodule FiveBells.StatisticsTest do
  use FiveBells.DataCase

  alias FiveBells.Statistics

  describe "time_series" do
    alias FiveBells.Statistics.TimeSeries

    @valid_attrs %{cycle: 42, entity_id: "some entity_id", entity_type: "some entity_type", key: "some key", label: "some label", simulation_id: "some simulation_id", value: 42}
    @update_attrs %{cycle: 43, entity_id: "some updated entity_id", entity_type: "some updated entity_type", key: "some updated key", label: "some updated label", simulation_id: "some updated simulation_id", value: 43}
    @invalid_attrs %{cycle: nil, entity_id: nil, entity_type: nil, key: nil, label: nil, simulation_id: nil, value: nil}

    def time_series_fixture(attrs \\ %{}) do
      {:ok, time_series} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Statistics.create_time_series()

      time_series
    end

    test "list_time_series/0 returns all time_series" do
      time_series = time_series_fixture()
      assert Statistics.list_time_series() == [time_series]
    end

    test "get_time_series!/1 returns the time_series with given id" do
      time_series = time_series_fixture()
      assert Statistics.get_time_series!(time_series.id) == time_series
    end

    test "create_time_series/1 with valid data creates a time_series" do
      assert {:ok, %TimeSeries{} = time_series} = Statistics.create_time_series(@valid_attrs)
      assert time_series.cycle == 42
      assert time_series.entity_id == "some entity_id"
      assert time_series.entity_type == "some entity_type"
      assert time_series.key == "some key"
      assert time_series.label == "some label"
      assert time_series.simulation_id == "some simulation_id"
      assert time_series.value == 42
    end

    test "create_time_series/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Statistics.create_time_series(@invalid_attrs)
    end

    test "update_time_series/2 with valid data updates the time_series" do
      time_series = time_series_fixture()
      assert {:ok, %TimeSeries{} = time_series} = Statistics.update_time_series(time_series, @update_attrs)
      assert time_series.cycle == 43
      assert time_series.entity_id == "some updated entity_id"
      assert time_series.entity_type == "some updated entity_type"
      assert time_series.key == "some updated key"
      assert time_series.label == "some updated label"
      assert time_series.simulation_id == "some updated simulation_id"
      assert time_series.value == 43
    end

    test "update_time_series/2 with invalid data returns error changeset" do
      time_series = time_series_fixture()
      assert {:error, %Ecto.Changeset{}} = Statistics.update_time_series(time_series, @invalid_attrs)
      assert time_series == Statistics.get_time_series!(time_series.id)
    end

    test "delete_time_series/1 deletes the time_series" do
      time_series = time_series_fixture()
      assert {:ok, %TimeSeries{}} = Statistics.delete_time_series(time_series)
      assert_raise Ecto.NoResultsError, fn -> Statistics.get_time_series!(time_series.id) end
    end

    test "change_time_series/1 returns a time_series changeset" do
      time_series = time_series_fixture()
      assert %Ecto.Changeset{} = Statistics.change_time_series(time_series)
    end
  end
end

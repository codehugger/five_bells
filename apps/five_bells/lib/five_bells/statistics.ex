defmodule FiveBells.Statistics do
  @moduledoc """
  The Statistics context.
  """

  import Ecto.Query, warn: false
  alias FiveBells.Repo

  alias FiveBells.Statistics.TimeSeries

  @doc """
  Returns the list of time_series.

  ## Examples

      iex> list_time_series()
      [%TimeSeries{}, ...]

  """
  def list_time_series do
    Repo.all(TimeSeries)
  end

  @doc """
  Gets a single time_series.

  Raises `Ecto.NoResultsError` if the Time series does not exist.

  ## Examples

      iex> get_time_series!(123)
      %TimeSeries{}

      iex> get_time_series!(456)
      ** (Ecto.NoResultsError)

  """
  def get_time_series!(id), do: Repo.get!(TimeSeries, id)

  @doc """
  Creates a time_series.

  ## Examples

      iex> create_time_series(%{field: value})
      {:ok, %TimeSeries{}}

      iex> create_time_series(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_time_series(attrs \\ %{}) do
    %TimeSeries{}
    |> TimeSeries.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a time_series.

  ## Examples

      iex> update_time_series(time_series, %{field: new_value})
      {:ok, %TimeSeries{}}

      iex> update_time_series(time_series, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_time_series(%TimeSeries{} = time_series, attrs) do
    time_series
    |> TimeSeries.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TimeSeries.

  ## Examples

      iex> delete_time_series(time_series)
      {:ok, %TimeSeries{}}

      iex> delete_time_series(time_series)
      {:error, %Ecto.Changeset{}}

  """
  def delete_time_series(%TimeSeries{} = time_series) do
    Repo.delete(time_series)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking time_series changes.

  ## Examples

      iex> change_time_series(time_series)
      %Ecto.Changeset{source: %TimeSeries{}}

  """
  def change_time_series(%TimeSeries{} = time_series) do
    TimeSeries.changeset(time_series, %{})
  end
end

defmodule Predictor.Odds do
  @moduledoc """
  Context functions for storing and querying append-only odds snapshots.

  Odds observations are stored as a historical time series in `odds_snapshots`.
  New provider observations should be inserted as new rows instead of updating a
  previously captured price so CLV, backtesting, and model-evaluation workflows
  can reconstruct odds movement over time.
  """

  import Ecto.Query

  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Repo

  @doc """
  Inserts an odds observation into the append-only `odds_snapshots` table.

  Callers may pass a provider timestamp in `captured_at`; when it is absent, the
  current system time is used. Duplicate observations with the same fixture,
  bookmaker, market, selection, and capture time are ignored.
  """
  def insert_odds_observation(attrs) when is_map(attrs) do
    attrs = Map.put_new_lazy(attrs, :captured_at, &system_captured_at/0)

    %OddsSnapshot{}
    |> OddsSnapshot.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:fixture_id, :bookmaker_id, :market_id, :selection_id, :captured_at]
    )
  end

  @doc """
  Returns the latest odds snapshot for each bookmaker/market/selection on a fixture.

  The optional second argument accepts filters for `:market_id`, `:bookmaker_id`,
  and `:selection_id`.
  """
  def latest_odds_for_fixture(fixture_id, opts \\ []) do
    fixture_id
    |> base_fixture_query(opts)
    |> distinct([o], [o.bookmaker_id, o.market_id, o.selection_id])
    |> order_by([o],
      asc: o.bookmaker_id,
      asc: o.market_id,
      asc: o.selection_id,
      desc: o.captured_at,
      desc: o.id
    )
    |> preload([:bookmaker, :market, :selection])
    |> Repo.all()
  end

  @doc """
  Returns the odds history for one fixture/market/bookmaker/selection tuple.

  Results are ordered chronologically for charting, CLV, backtesting, and model
  evaluation.
  """
  def odds_history(fixture_id, market_id, bookmaker_id, selection_id) do
    from(o in OddsSnapshot,
      where:
        o.fixture_id == ^fixture_id and o.market_id == ^market_id and
          o.bookmaker_id == ^bookmaker_id and o.selection_id == ^selection_id,
      order_by: [asc: o.captured_at, asc: o.id],
      preload: [:bookmaker, :market, :selection]
    )
    |> Repo.all()
  end

  defp base_fixture_query(fixture_id, opts) do
    Enum.reduce(opts, from(o in OddsSnapshot, where: o.fixture_id == ^fixture_id), fn
      {:market_id, market_id}, query -> where(query, [o], o.market_id == ^market_id)
      {:bookmaker_id, bookmaker_id}, query -> where(query, [o], o.bookmaker_id == ^bookmaker_id)
      {:selection_id, selection_id}, query -> where(query, [o], o.selection_id == ^selection_id)
      {_key, _value}, query -> query
    end)
  end

  defp system_captured_at, do: DateTime.utc_now() |> DateTime.truncate(:second)
end

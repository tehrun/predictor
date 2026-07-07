defmodule Predictor.Odds do
  @moduledoc """
  Context functions for storing and querying append-only odds snapshots.

  Odds observations are stored as a historical time series in `odds_snapshots`.
  New provider observations should be inserted as new rows instead of updating a
  previously captured price so CLV, backtesting, and model-evaluation workflows
  can reconstruct odds movement over time.
  """

  import Ecto.Query

  alias Predictor.Betting.Bet
  alias Predictor.Odds.{ClosingLine, ClosingLineTrackerWorker, OddsSnapshot}
  alias Predictor.Value.ValueRecommendation
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
  def latest_odds_before_kickoff(fixture_id, bookmaker_id, market_id, selection_id) do
    kickoff_query =
      from(f in Predictor.Catalog.Fixture, where: f.id == ^fixture_id, select: f.kickoff_at)

    from(o in OddsSnapshot,
      where:
        o.fixture_id == ^fixture_id and o.bookmaker_id == ^bookmaker_id and
          o.market_id == ^market_id and o.selection_id == ^selection_id and
          o.captured_at <= subquery(kickoff_query),
      order_by: [desc: o.captured_at, desc: o.id],
      limit: 1
    )
    |> Repo.one()
  end

  def upsert_closing_line_from_latest_odds(fixture_id, bookmaker_id, market_id, selection_id) do
    case latest_odds_before_kickoff(fixture_id, bookmaker_id, market_id, selection_id) do
      nil ->
        {:error, :closing_odds_not_found}

      snapshot ->
        attrs = %{
          fixture_id: fixture_id,
          bookmaker_id: bookmaker_id,
          market_id: market_id,
          selection_id: selection_id,
          decimal_odds: snapshot.decimal_odds,
          captured_at: snapshot.captured_at
        }

        %ClosingLine{}
        |> ClosingLine.changeset(attrs)
        |> Repo.insert(
          on_conflict: {:replace, [:decimal_odds, :captured_at, :updated_at]},
          conflict_target: [:fixture_id, :bookmaker_id, :market_id, :selection_id]
        )
    end
  end

  def capture_closing_line_for_position(fixture_id, bookmaker_id, market_id, selection_id) do
    with {:ok, closing_line} <-
           upsert_closing_line_from_latest_odds(fixture_id, bookmaker_id, market_id, selection_id) do
      update_recommendation_clv(closing_line)
      update_bet_clv(closing_line)
      {:ok, closing_line}
    end
  end

  def schedule_closing_line_tracking(%ValueRecommendation{} = recommendation) do
    recommendation = Repo.preload(recommendation, :fixture)

    %{
      "fixture_id" => recommendation.fixture_id,
      "bookmaker_id" => recommendation.bookmaker_id,
      "market_id" => recommendation.market_id,
      "selection_id" => recommendation.selection_id
    }
    |> ClosingLineTrackerWorker.new(
      scheduled_at: tracking_at(recommendation.fixture.kickoff_at),
      unique: [period: :infinity, fields: [:worker, :args]]
    )
    |> Oban.insert()
  end

  def schedule_closing_line_tracking(%Bet{} = bet) do
    bet = Repo.preload(bet, :fixture)

    %{
      "fixture_id" => bet.fixture_id,
      "bookmaker_id" => bet.bookmaker_id,
      "market_id" => bet.market_id,
      "selection_id" => bet.selection_id
    }
    |> ClosingLineTrackerWorker.new(
      scheduled_at: tracking_at(bet.fixture.kickoff_at),
      unique: [period: :infinity, fields: [:worker, :args]]
    )
    |> Oban.insert()
  end

  def clv_analytics do
    from(b in Bet,
      where: not is_nil(b.clv_decimal_odds),
      select: %{
        tracked_bets: count(b.id),
        average_decimal_clv: avg(b.clv_decimal_odds),
        average_probability_clv: avg(b.clv_implied_probability),
        average_percentage_clv: avg(b.clv_percentage),
        positive_clv_bets: filter(count(b.id), b.clv_decimal_odds > 0)
      }
    )
    |> Repo.one()
  end

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

  defp update_recommendation_clv(closing_line) do
    now = system_captured_at()

    from(r in ValueRecommendation,
      where:
        r.fixture_id == ^closing_line.fixture_id and r.bookmaker_id == ^closing_line.bookmaker_id and
          r.market_id == ^closing_line.market_id and r.selection_id == ^closing_line.selection_id,
      update: [
        set: [
          closing_odds: ^closing_line.decimal_odds,
          clv_decimal_odds: fragment("? - ?", r.odds, ^closing_line.decimal_odds),
          clv_implied_probability:
            fragment("(1.0 / ?) - (1.0 / ?)", ^closing_line.decimal_odds, r.odds),
          clv_percentage: fragment("((? / ?) - 1.0) * 100.0", r.odds, ^closing_line.decimal_odds),
          updated_at: ^now
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp update_bet_clv(closing_line) do
    now = system_captured_at()

    from(b in Bet,
      where:
        b.fixture_id == ^closing_line.fixture_id and b.bookmaker_id == ^closing_line.bookmaker_id and
          b.market_id == ^closing_line.market_id and b.selection_id == ^closing_line.selection_id,
      update: [
        set: [
          closing_odds: ^closing_line.decimal_odds,
          clv_decimal_odds: fragment("? - ?", b.odds_taken, ^closing_line.decimal_odds),
          clv_implied_probability:
            fragment("(1.0 / ?) - (1.0 / ?)", ^closing_line.decimal_odds, b.odds_taken),
          clv_percentage:
            fragment("((? / ?) - 1.0) * 100.0", b.odds_taken, ^closing_line.decimal_odds),
          updated_at: ^now
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp tracking_at(kickoff_at) do
    candidate = DateTime.add(kickoff_at, -300, :second)
    now = system_captured_at()

    if DateTime.compare(candidate, now) == :gt, do: candidate, else: now
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

defmodule Predictor.Value.RecommendationEngine do
  @moduledoc """
  Creates value recommendations by comparing latest bookmaker prices with latest fair probabilities.

  Expected value is calculated as `EV = probability * odds - 1` using decimal odds.
  """

  import Ecto.Query

  alias Predictor.Catalog.Fixture
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Repo
  alias Predictor.Value.{Calculator, FairOdd, ValueRecommendation}

  @default_minimum_ev Decimal.new("0.05")
  @default_confidence_score Decimal.new("0.50")
  @default_status "new"

  @doc """
  Loads latest bookmaker odds, compares them with latest fair odds, and upserts recommendations.

  Supported options:

    * `:minimum_ev` - minimum expected value, defaults to `0.05`.
    * `:minimum_odds` - optional minimum decimal odds.
    * `:maximum_odds` - optional maximum decimal odds.
    * `:league_ids` - optional allowed league ids.
    * `:bookmaker_ids` - optional allowed bookmaker ids.
    * `:market_ids` - optional allowed market ids.
    * `:recommended_at` - timestamp to store, defaults to now.
    * `:confidence_score` - confidence score to store, defaults to `0.50`.
  """
  def create_or_update_recommendations(opts \\ []) do
    recommended_at = Keyword.get_lazy(opts, :recommended_at, &timestamp/0)

    recommendations =
      opts
      |> latest_value_rows_query()
      |> Repo.all()
      |> Enum.map(&recommendation_attrs(&1, opts, recommended_at))
      |> Enum.filter(&passes_thresholds?(&1, opts))
      |> Enum.map(&upsert_recommendation/1)

    collect_results(recommendations)
  end

  defp latest_value_rows_query(opts) do
    latest_odds =
      from(o in OddsSnapshot,
        distinct: [o.fixture_id, o.bookmaker_id, o.market_id, o.selection_id],
        order_by: [
          asc: o.fixture_id,
          asc: o.bookmaker_id,
          asc: o.market_id,
          asc: o.selection_id,
          desc: o.captured_at,
          desc: o.id
        ]
      )
      |> filter_in(:bookmaker_id, Keyword.get(opts, :bookmaker_ids))
      |> filter_in(:market_id, Keyword.get(opts, :market_ids))

    latest_fair_odds =
      from(f in FairOdd,
        distinct: [f.fixture_id, f.market_id, f.selection_id],
        order_by: [
          asc: f.fixture_id,
          asc: f.market_id,
          asc: f.selection_id,
          desc: f.calculated_at,
          desc: f.id
        ]
      )
      |> filter_in(:market_id, Keyword.get(opts, :market_ids))

    from(o in subquery(latest_odds),
      join: f in subquery(latest_fair_odds),
      on:
        f.fixture_id == o.fixture_id and f.market_id == o.market_id and
          f.selection_id == o.selection_id,
      join: fixture in Fixture,
      on: fixture.id == o.fixture_id,
      select: %{odds_snapshot: o, fair_odd: f, league_id: fixture.league_id}
    )
    |> filter_in(:league_id, Keyword.get(opts, :league_ids))
  end

  defp recommendation_attrs(%{odds_snapshot: odds, fair_odd: fair_odd}, opts, recommended_at) do
    ev = Calculator.expected_value(odds.decimal_odds, fair_odd.implied_probability)

    %{
      fixture_id: odds.fixture_id,
      bookmaker_id: odds.bookmaker_id,
      market_id: odds.market_id,
      selection_id: odds.selection_id,
      odds_snapshot_id: odds.id,
      fair_odds_id: fair_odd.id,
      odds: odds.decimal_odds,
      fair_probability: fair_odd.implied_probability,
      fair_odds: fair_odd.fair_odds,
      ev: Decimal.round(ev, 6),
      ev_percentage: Decimal.round(Decimal.mult(ev, Decimal.new(100)), 4),
      confidence_score: decimal_option(opts, :confidence_score, @default_confidence_score),
      recommended_stake: decimal_option(opts, :recommended_stake, Decimal.new(0)),
      status: Keyword.get(opts, :status, @default_status),
      recommended_at: recommended_at
    }
  end

  defp passes_thresholds?(attrs, opts) do
    decimal_compare(attrs.ev, decimal_option(opts, :minimum_ev, @default_minimum_ev)) != :lt and
      passes_minimum_odds?(attrs.odds, Keyword.get(opts, :minimum_odds)) and
      passes_maximum_odds?(attrs.odds, Keyword.get(opts, :maximum_odds))
  end

  defp passes_minimum_odds?(_odds, nil), do: true

  defp passes_minimum_odds?(odds, minimum),
    do: decimal_compare(odds, decimal_value(minimum)) != :lt

  defp passes_maximum_odds?(_odds, nil), do: true

  defp passes_maximum_odds?(odds, maximum),
    do: decimal_compare(odds, decimal_value(maximum)) != :gt

  defp upsert_recommendation(attrs) do
    %ValueRecommendation{}
    |> ValueRecommendation.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, updatable_fields()},
      conflict_target: [:fixture_id, :bookmaker_id, :market_id, :selection_id]
    )
  end

  defp updatable_fields do
    [
      :odds_snapshot_id,
      :fair_odds_id,
      :odds,
      :fair_probability,
      :fair_odds,
      :ev,
      :ev_percentage,
      :confidence_score,
      :recommended_stake,
      :status,
      :recommended_at,
      :updated_at
    ]
  end

  defp filter_in(query, _field, nil), do: query
  defp filter_in(query, _field, []), do: query

  defp filter_in(query, field, values) do
    from(row in query, where: field(row, ^field) in ^values)
  end

  defp decimal_option(opts, key, default),
    do: opts |> Keyword.get(key, default) |> decimal_value()

  defp decimal_value(%Decimal{} = value), do: value
  defp decimal_value(value), do: Decimal.new(to_string(value))

  defp decimal_compare(left, right),
    do: left |> decimal_value() |> Decimal.compare(decimal_value(right))

  defp collect_results(results) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, recommendation} -> recommendation end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.truncate(:second)
end

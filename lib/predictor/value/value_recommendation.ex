defmodule Predictor.Value.ValueRecommendation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Bookmaker, Fixture}
  alias Predictor.Markets.{Market, Selection}
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Value.FairOdd

  schema "value_recommendations" do
    field(:ev_percentage, :decimal)
    field(:confidence_score, :decimal)
    field(:recommended_stake, :decimal)
    field(:status, :string, default: "open")
    field(:recommended_at, :utc_datetime)

    belongs_to(:fixture, Fixture)
    belongs_to(:bookmaker, Bookmaker)
    belongs_to(:market, Market)
    belongs_to(:selection, Selection)
    belongs_to(:odds_snapshot, OddsSnapshot)
    belongs_to(:fair_odd, FairOdd, foreign_key: :fair_odds_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(value_recommendation, attrs) do
    value_recommendation
    |> cast(attrs, [
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :odds_snapshot_id,
      :fair_odds_id,
      :ev_percentage,
      :confidence_score,
      :recommended_stake,
      :status,
      :recommended_at
    ])
    |> validate_required([
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :ev_percentage,
      :confidence_score,
      :recommended_stake,
      :status,
      :recommended_at
    ])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:recommended_stake, greater_than_or_equal_to: 0)
    |> assoc_constraint(:fixture)
    |> assoc_constraint(:bookmaker)
    |> assoc_constraint(:market)
    |> assoc_constraint(:selection)
    |> assoc_constraint(:odds_snapshot)
    |> assoc_constraint(:fair_odd)
    |> unique_constraint([:fixture_id, :bookmaker_id, :market_id, :selection_id, :recommended_at],
      name: :value_recommendations_dedup_index
    )
  end
end

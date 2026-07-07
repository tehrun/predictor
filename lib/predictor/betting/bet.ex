defmodule Predictor.Betting.Bet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Bookmaker, Fixture}
  alias Predictor.Markets.{Market, Selection}
  alias Predictor.Value.ValueRecommendation

  schema "bets" do
    field(:stake, :decimal)
    field(:odds_taken, :decimal)
    field(:placed_at, :utc_datetime)
    field(:status, :string, default: "placed")
    field(:result, :string)
    field(:profit_loss, :decimal)
    field(:closing_odds, :decimal)
    field(:clv_decimal_odds, :decimal)
    field(:clv_implied_probability, :decimal)
    field(:clv_percentage, :decimal)

    belongs_to(:value_recommendation, ValueRecommendation)
    belongs_to(:fixture, Fixture)
    belongs_to(:bookmaker, Bookmaker)
    belongs_to(:market, Market)
    belongs_to(:selection, Selection)

    timestamps(type: :utc_datetime)
  end

  def changeset(bet, attrs) do
    bet
    |> cast(attrs, [
      :value_recommendation_id,
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :stake,
      :odds_taken,
      :placed_at,
      :status,
      :result,
      :profit_loss,
      :closing_odds,
      :clv_decimal_odds,
      :clv_implied_probability,
      :clv_percentage
    ])
    |> validate_required([
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :stake,
      :odds_taken,
      :placed_at,
      :status
    ])
    |> validate_number(:stake, greater_than: 0)
    |> validate_number(:odds_taken, greater_than: 1)
    |> validate_number(:closing_odds, greater_than: 1)
    |> assoc_constraint(:value_recommendation)
    |> assoc_constraint(:fixture)
    |> assoc_constraint(:bookmaker)
    |> assoc_constraint(:market)
    |> assoc_constraint(:selection)
  end
end

defmodule Predictor.Value.FairOdd do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.Fixture
  alias Predictor.Markets.{Market, Selection}

  schema "fair_odds" do
    field(:implied_probability, :decimal)
    field(:fair_odds, :decimal)
    field(:source_engine, :string)
    field(:calculated_at, :utc_datetime)

    belongs_to(:fixture, Fixture)
    belongs_to(:market, Market)
    belongs_to(:selection, Selection)

    timestamps(type: :utc_datetime)
  end

  def changeset(fair_odd, attrs) do
    fair_odd
    |> cast(attrs, [
      :fixture_id,
      :market_id,
      :selection_id,
      :implied_probability,
      :fair_odds,
      :source_engine,
      :calculated_at
    ])
    |> validate_required([
      :fixture_id,
      :market_id,
      :selection_id,
      :implied_probability,
      :fair_odds,
      :source_engine,
      :calculated_at
    ])
    |> validate_number(:implied_probability, greater_than: 0, less_than: 1)
    |> validate_number(:fair_odds, greater_than: 1)
    |> assoc_constraint(:fixture)
    |> assoc_constraint(:market)
    |> assoc_constraint(:selection)
    |> unique_constraint([:fixture_id, :market_id, :selection_id, :source_engine, :calculated_at],
      name: :fair_odds_dedup_index
    )
  end
end

defmodule Predictor.Odds.OddsSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Bookmaker, Fixture}
  alias Predictor.Markets.{Market, Selection}

  schema "odds_snapshots" do
    field(:decimal_odds, :decimal)
    field(:captured_at, :utc_datetime)
    field(:external_provider, :string)
    field(:external_id, :string)

    belongs_to(:fixture, Fixture)
    belongs_to(:bookmaker, Bookmaker)
    belongs_to(:market, Market)
    belongs_to(:selection, Selection)

    timestamps(type: :utc_datetime)
  end

  def changeset(odds_snapshot, attrs) do
    odds_snapshot
    |> cast(attrs, [
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :decimal_odds,
      :captured_at,
      :external_provider,
      :external_id
    ])
    |> validate_required([
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :decimal_odds,
      :captured_at
    ])
    |> validate_number(:decimal_odds, greater_than: 1)
    |> assoc_constraint(:fixture)
    |> assoc_constraint(:bookmaker)
    |> assoc_constraint(:market)
    |> assoc_constraint(:selection)
    |> unique_constraint([:fixture_id, :bookmaker_id, :market_id, :selection_id, :captured_at],
      name: :odds_snapshots_dedup_index
    )
    |> unique_constraint([:external_provider, :external_id])
  end
end

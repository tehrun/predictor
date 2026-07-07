defmodule Predictor.Odds.ClosingLine do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Bookmaker, Fixture}
  alias Predictor.Markets.{Market, Selection}

  schema "closing_lines" do
    field(:decimal_odds, :decimal)
    field(:captured_at, :utc_datetime)

    belongs_to(:fixture, Fixture)
    belongs_to(:bookmaker, Bookmaker)
    belongs_to(:market, Market)
    belongs_to(:selection, Selection)

    timestamps(type: :utc_datetime)
  end

  def changeset(closing_line, attrs) do
    closing_line
    |> cast(attrs, [
      :fixture_id,
      :bookmaker_id,
      :market_id,
      :selection_id,
      :decimal_odds,
      :captured_at
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
    |> unique_constraint([:fixture_id, :bookmaker_id, :market_id, :selection_id],
      name: :closing_lines_dedup_index
    )
  end
end

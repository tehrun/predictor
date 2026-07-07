defmodule Predictor.Catalog.League do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Fixture, Sport}

  schema "leagues" do
    field(:name, :string)
    field(:slug, :string)
    field(:country, :string)
    field(:season, :string)
    field(:external_provider, :string)
    field(:external_id, :string)

    belongs_to(:sport, Sport)
    has_many(:fixtures, Fixture)

    timestamps(type: :utc_datetime)
  end

  def changeset(league, attrs) do
    league
    |> cast(attrs, [:sport_id, :name, :slug, :country, :season, :external_provider, :external_id])
    |> validate_required([:sport_id, :name, :slug])
    |> assoc_constraint(:sport)
    |> unique_constraint([:sport_id, :slug, :season])
    |> unique_constraint([:external_provider, :external_id])
  end
end

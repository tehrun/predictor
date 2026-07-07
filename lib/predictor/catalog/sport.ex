defmodule Predictor.Catalog.Sport do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{League, Team}
  alias Predictor.Markets.Market

  schema "sports" do
    field(:name, :string)
    field(:slug, :string)
    field(:external_provider, :string)
    field(:external_id, :string)

    has_many(:leagues, League)
    has_many(:teams, Team)
    has_many(:markets, Market)

    timestamps(type: :utc_datetime)
  end

  def changeset(sport, attrs) do
    sport
    |> cast(attrs, [:name, :slug, :external_provider, :external_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> unique_constraint([:external_provider, :external_id])
  end
end

defmodule Predictor.Catalog.Team do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{Fixture, Sport}

  schema "teams" do
    field(:name, :string)
    field(:slug, :string)
    field(:country, :string)
    field(:external_provider, :string)
    field(:external_id, :string)

    belongs_to(:sport, Sport)
    has_many(:home_fixtures, Fixture, foreign_key: :home_team_id)
    has_many(:away_fixtures, Fixture, foreign_key: :away_team_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:sport_id, :name, :slug, :country, :external_provider, :external_id])
    |> validate_required([:sport_id, :name, :slug])
    |> assoc_constraint(:sport)
    |> unique_constraint([:sport_id, :slug])
    |> unique_constraint([:external_provider, :external_id])
  end
end

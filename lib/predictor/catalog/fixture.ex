defmodule Predictor.Catalog.Fixture do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.{League, Team}
  alias Predictor.Odds.OddsSnapshot

  schema "fixtures" do
    field(:kickoff_at, :utc_datetime)
    field(:status, :string, default: "scheduled")
    field(:external_provider, :string)
    field(:external_id, :string)

    belongs_to(:league, League)
    belongs_to(:home_team, Team)
    belongs_to(:away_team, Team)
    has_many(:odds_snapshots, OddsSnapshot)

    timestamps(type: :utc_datetime)
  end

  def changeset(fixture, attrs) do
    fixture
    |> cast(attrs, [
      :league_id,
      :home_team_id,
      :away_team_id,
      :kickoff_at,
      :status,
      :external_provider,
      :external_id
    ])
    |> validate_required([:league_id, :home_team_id, :away_team_id, :kickoff_at, :status])
    |> assoc_constraint(:league)
    |> assoc_constraint(:home_team)
    |> assoc_constraint(:away_team)
    |> unique_constraint([:external_provider, :external_id])
    |> unique_constraint([:league_id, :home_team_id, :away_team_id, :kickoff_at],
      name: :fixtures_natural_key_index
    )
  end
end

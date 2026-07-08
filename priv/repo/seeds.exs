import Ecto.Query

alias Predictor.Catalog.{Bookmaker, Fixture, League, Sport, Team}
alias Predictor.Markets.{Market, Selection}
alias Predictor.Repo
alias Predictor.Value.ValueRecommendation

now = DateTime.utc_now() |> DateTime.truncate(:second)
kickoff_at = DateTime.new!(Date.utc_today(), ~T[19:45:00], "Etc/UTC")

upsert = fn schema, attrs, conflict_target ->
  changeset = schema.changeset(struct(schema), attrs)

  {:ok, record} =
    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: conflict_target,
      returning: true
    )

  record
end

sport =
  upsert.(
    Sport,
    %{name: "Football", slug: "football", external_provider: "seed", external_id: "football"},
    [:slug]
  )

league =
  upsert.(
    League,
    %{
      sport_id: sport.id,
      name: "Demo Premier League",
      slug: "demo-premier-league",
      country: "GB",
      season: "2026",
      external_provider: "seed",
      external_id: "demo-premier-league-2026"
    },
    [:sport_id, :slug, :season]
  )

home_team =
  upsert.(
    Team,
    %{
      sport_id: sport.id,
      name: "Northbridge FC",
      slug: "northbridge-fc",
      country: "GB",
      external_provider: "seed",
      external_id: "northbridge-fc"
    },
    [:sport_id, :slug]
  )

away_team =
  upsert.(
    Team,
    %{
      sport_id: sport.id,
      name: "Riverside United",
      slug: "riverside-united",
      country: "GB",
      external_provider: "seed",
      external_id: "riverside-united"
    },
    [:sport_id, :slug]
  )

fixture =
  upsert.(
    Fixture,
    %{
      league_id: league.id,
      home_team_id: home_team.id,
      away_team_id: away_team.id,
      kickoff_at: kickoff_at,
      status: "scheduled",
      external_provider: "seed",
      external_id: "northbridge-riverside-today"
    },
    [:league_id, :home_team_id, :away_team_id, :kickoff_at]
  )

bookmaker =
  upsert.(
    Bookmaker,
    %{
      name: "Demo Sportsbook",
      slug: "demo-sportsbook",
      external_provider: "seed",
      external_id: "demo-sportsbook"
    },
    [:slug]
  )

market =
  upsert.(
    Market,
    %{
      sport_id: sport.id,
      name: "Match Winner",
      key: "h2h",
      description: "Football 1X2 match winner market"
    },
    [:sport_id, :key]
  )

selection =
  upsert.(
    Selection,
    %{market_id: market.id, name: home_team.name, key: "home", sort_order: 1},
    [:market_id, :key]
  )

attrs = %{
  fixture_id: fixture.id,
  bookmaker_id: bookmaker.id,
  market_id: market.id,
  selection_id: selection.id,
  odds: Decimal.new("2.35"),
  fair_probability: Decimal.new("0.48"),
  fair_odds: Decimal.new("2.08"),
  ev: Decimal.new("0.1280"),
  ev_percentage: Decimal.new("12.80"),
  confidence_score: Decimal.new("0.82"),
  recommended_stake: Decimal.new("25.00"),
  status: "new",
  recommended_at: now
}

{:ok, _recommendation} =
  %ValueRecommendation{}
  |> ValueRecommendation.changeset(attrs)
  |> Repo.insert(
    on_conflict:
      {:replace, Map.keys(attrs) -- [:fixture_id, :bookmaker_id, :market_id, :selection_id]},
    conflict_target: [:fixture_id, :bookmaker_id, :market_id, :selection_id]
  )

count =
  Repo.aggregate(
    from(r in ValueRecommendation, where: r.status in ["new", "notified", "accepted", "open"]),
    :count
  )

IO.puts("Seeded dashboard demo data. Actionable recommendations: #{count}")

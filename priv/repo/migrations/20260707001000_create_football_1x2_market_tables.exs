defmodule Predictor.Repo.Migrations.CreateFootball1x2MarketTables do
  use Ecto.Migration

  def change do
    create table(:sports) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sports, [:slug])
    create unique_index(:sports, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")

    create table(:leagues) do
      add :sport_id, references(:sports, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :country, :string
      add :season, :string
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:leagues, [:sport_id])
    create unique_index(:leagues, [:sport_id, :slug, :season])
    create unique_index(:leagues, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")

    create table(:teams) do
      add :sport_id, references(:sports, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :country, :string
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:sport_id])
    create unique_index(:teams, [:sport_id, :slug])
    create unique_index(:teams, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")

    create table(:fixtures) do
      add :league_id, references(:leagues, on_delete: :restrict), null: false
      add :home_team_id, references(:teams, on_delete: :restrict), null: false
      add :away_team_id, references(:teams, on_delete: :restrict), null: false
      add :kickoff_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "scheduled"
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:fixtures, [:league_id])
    create index(:fixtures, [:home_team_id])
    create index(:fixtures, [:away_team_id])
    create index(:fixtures, [:kickoff_at])
    create unique_index(:fixtures, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")
    create unique_index(:fixtures, [:league_id, :home_team_id, :away_team_id, :kickoff_at], name: :fixtures_natural_key_index)

    create table(:bookmakers) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bookmakers, [:slug])
    create unique_index(:bookmakers, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")

    create table(:markets) do
      add :sport_id, references(:sports, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :key, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:markets, [:sport_id])
    create unique_index(:markets, [:sport_id, :key])

    create table(:selections) do
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :key, :string, null: false
      add :sort_order, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:selections, [:market_id])
    create unique_index(:selections, [:market_id, :key])

    create table(:odds_snapshots) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :bookmaker_id, references(:bookmakers, on_delete: :restrict), null: false
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :selection_id, references(:selections, on_delete: :restrict), null: false
      add :decimal_odds, :decimal, precision: 12, scale: 4, null: false
      add :captured_at, :utc_datetime, null: false
      add :external_provider, :string
      add :external_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:odds_snapshots, [:fixture_id, :market_id, :bookmaker_id, :selection_id, :captured_at],
             name: :odds_snapshots_lookup_index
           )

    create index(:odds_snapshots, [:fixture_id, :market_id, :captured_at],
             name: :odds_snapshots_fixture_market_time_index
           )

    create index(:odds_snapshots, [:bookmaker_id, :captured_at],
             name: :odds_snapshots_bookmaker_time_index
           )

    create index(:odds_snapshots, [:selection_id, :captured_at],
             name: :odds_snapshots_selection_time_index
           )
    create unique_index(:odds_snapshots, [:fixture_id, :bookmaker_id, :market_id, :selection_id, :captured_at], name: :odds_snapshots_dedup_index)
    create unique_index(:odds_snapshots, [:external_provider, :external_id], where: "external_provider IS NOT NULL AND external_id IS NOT NULL")

    create table(:fair_odds) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :selection_id, references(:selections, on_delete: :restrict), null: false
      add :implied_probability, :decimal, precision: 8, scale: 6, null: false
      add :fair_odds, :decimal, precision: 12, scale: 4, null: false
      add :source_engine, :string, null: false
      add :calculated_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:fair_odds, [:fixture_id, :market_id, :calculated_at])
    create unique_index(:fair_odds, [:fixture_id, :market_id, :selection_id, :source_engine, :calculated_at], name: :fair_odds_dedup_index)

    create table(:value_recommendations) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :bookmaker_id, references(:bookmakers, on_delete: :restrict), null: false
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :selection_id, references(:selections, on_delete: :restrict), null: false
      add :odds_snapshot_id, references(:odds_snapshots, on_delete: :nilify_all)
      add :fair_odds_id, references(:fair_odds, on_delete: :nilify_all)
      add :ev_percentage, :decimal, precision: 8, scale: 4, null: false
      add :confidence_score, :decimal, precision: 6, scale: 4, null: false
      add :recommended_stake, :decimal, precision: 12, scale: 2, null: false
      add :status, :string, null: false, default: "open"
      add :recommended_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:value_recommendations, [:fixture_id, :market_id, :status])
    create index(:value_recommendations, [:bookmaker_id])
    create unique_index(:value_recommendations, [:fixture_id, :bookmaker_id, :market_id, :selection_id, :recommended_at], name: :value_recommendations_dedup_index)

    create table(:bets) do
      add :value_recommendation_id, references(:value_recommendations, on_delete: :nilify_all)
      add :fixture_id, references(:fixtures, on_delete: :restrict), null: false
      add :bookmaker_id, references(:bookmakers, on_delete: :restrict), null: false
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :selection_id, references(:selections, on_delete: :restrict), null: false
      add :stake, :decimal, precision: 12, scale: 2, null: false
      add :odds_taken, :decimal, precision: 12, scale: 4, null: false
      add :placed_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "placed"
      add :result, :string
      add :profit_loss, :decimal, precision: 12, scale: 2
      add :closing_odds, :decimal, precision: 12, scale: 4

      timestamps(type: :utc_datetime)
    end

    create index(:bets, [:fixture_id, :market_id])
    create index(:bets, [:bookmaker_id])
    create index(:bets, [:status])

    create table(:closing_lines) do
      add :fixture_id, references(:fixtures, on_delete: :delete_all), null: false
      add :bookmaker_id, references(:bookmakers, on_delete: :restrict), null: false
      add :market_id, references(:markets, on_delete: :restrict), null: false
      add :selection_id, references(:selections, on_delete: :restrict), null: false
      add :decimal_odds, :decimal, precision: 12, scale: 4, null: false
      add :captured_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:closing_lines, [:fixture_id, :market_id])
    create unique_index(:closing_lines, [:fixture_id, :bookmaker_id, :market_id, :selection_id], name: :closing_lines_dedup_index)
  end
end

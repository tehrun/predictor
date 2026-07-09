defmodule PredictorWeb.LiveFixtures do
  alias Predictor.Repo
  alias Predictor.Betting.Bet
  alias Predictor.Catalog.{Bookmaker, Fixture, League, Sport, Team}
  alias Predictor.Markets.{Market, Selection}
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Value.ValueRecommendation

  def fixture_setup(attrs \\ %{}) do
    suffix = unique_suffix()
    sport = insert!(%Sport{name: "Football #{suffix}", slug: "football-#{suffix}"})

    league =
      insert!(%League{
        sport_id: sport.id,
        name: "Premier Test League",
        slug: "premier-test-#{suffix}",
        season: "2026"
      })

    home_team =
      insert!(%Team{
        sport_id: sport.id,
        name: Map.get(attrs, :home_team_name, "Home United"),
        slug: "home-#{suffix}"
      })

    away_team =
      insert!(%Team{
        sport_id: sport.id,
        name: Map.get(attrs, :away_team_name, "Away City"),
        slug: "away-#{suffix}"
      })

    fixture =
      insert!(%Fixture{
        league_id: league.id,
        home_team_id: home_team.id,
        away_team_id: away_team.id,
        kickoff_at:
          Map.get(
            attrs,
            :kickoff_at,
            DateTime.utc_now()
            |> DateTime.add(2 * 24 * 60 * 60, :second)
            |> DateTime.truncate(:second)
          ),
        status: Map.get(attrs, :status, "scheduled")
      })

    market = insert!(%Market{sport_id: sport.id, name: "Match Winner", key: "h2h-#{suffix}"})

    home_selection =
      insert!(%Selection{market_id: market.id, name: home_team.name, key: "home", sort_order: 1})

    away_selection =
      insert!(%Selection{market_id: market.id, name: away_team.name, key: "away", sort_order: 2})

    draw_selection =
      insert!(%Selection{market_id: market.id, name: "Draw", key: "draw", sort_order: 3})

    bookmaker = insert!(%Bookmaker{name: "TestBook", slug: "testbook-#{suffix}"})
    other_bookmaker = insert!(%Bookmaker{name: "SharpBook", slug: "sharpbook-#{suffix}"})

    %{
      sport: sport,
      league: league,
      home_team: home_team,
      away_team: away_team,
      fixture: fixture,
      market: market,
      selection: home_selection,
      home_selection: home_selection,
      away_selection: away_selection,
      draw_selection: draw_selection,
      bookmaker: bookmaker,
      other_bookmaker: other_bookmaker
    }
  end

  def insert_odds(context, attrs \\ %{}) do
    insert!(%OddsSnapshot{
      fixture_id: Map.get(attrs, :fixture_id, context.fixture.id),
      bookmaker_id: Map.get(attrs, :bookmaker_id, context.bookmaker.id),
      market_id: Map.get(attrs, :market_id, context.market.id),
      selection_id: Map.get(attrs, :selection_id, context.selection.id),
      decimal_odds: decimal(Map.get(attrs, :decimal_odds, "2.10")),
      captured_at:
        Map.get(
          attrs,
          :captured_at,
          DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
        )
    })
  end

  def insert_recommendation(context, attrs \\ %{}) do
    insert!(%ValueRecommendation{
      fixture_id: Map.get(attrs, :fixture_id, context.fixture.id),
      bookmaker_id: Map.get(attrs, :bookmaker_id, context.bookmaker.id),
      market_id: Map.get(attrs, :market_id, context.market.id),
      selection_id: Map.get(attrs, :selection_id, context.selection.id),
      odds: decimal(Map.get(attrs, :odds, "2.40")),
      fair_probability: decimal(Map.get(attrs, :fair_probability, "0.50")),
      fair_odds: decimal(Map.get(attrs, :fair_odds, "2.00")),
      ev: decimal(Map.get(attrs, :ev, "0.20")),
      ev_percentage: decimal(Map.get(attrs, :ev_percentage, "20.00")),
      confidence_score: decimal(Map.get(attrs, :confidence_score, "0.82")),
      recommended_stake: decimal(Map.get(attrs, :recommended_stake, "15.50")),
      status: Map.get(attrs, :status, "new"),
      recommended_at:
        Map.get(attrs, :recommended_at, DateTime.utc_now() |> DateTime.truncate(:second))
    })
  end

  def insert_bet(context, attrs \\ %{}) do
    insert!(%Bet{
      fixture_id: Map.get(attrs, :fixture_id, context.fixture.id),
      bookmaker_id: Map.get(attrs, :bookmaker_id, context.bookmaker.id),
      market_id: Map.get(attrs, :market_id, context.market.id),
      selection_id: Map.get(attrs, :selection_id, context.selection.id),
      stake: decimal(Map.get(attrs, :stake, "25.00")),
      odds_taken: decimal(Map.get(attrs, :odds_taken, "2.25")),
      placed_at:
        Map.get(
          attrs,
          :placed_at,
          DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
        ),
      status: Map.get(attrs, :status, "accepted"),
      result: Map.get(attrs, :result, "won"),
      profit_loss: decimal(Map.get(attrs, :profit_loss, "31.25")),
      clv_percentage: decimal(Map.get(attrs, :clv_percentage, "4.50"))
    })
  end

  defp insert!(struct), do: Repo.insert!(struct)
  defp decimal(%Decimal{} = value), do: value
  defp decimal(value), do: Decimal.new(to_string(value))
  defp unique_suffix, do: System.unique_integer([:positive, :monotonic])
end

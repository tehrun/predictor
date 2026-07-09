defmodule PredictorWeb.DashboardLiveTest do
  use PredictorWeb.ConnCase

  test "/ and /dashboard load successfully", %{conn: conn} do
    assert {:ok, _view, root_html} = live(conn, ~p"/")
    assert root_html =~ "Upcoming qualifying value bets"

    assert {:ok, _view, dashboard_html} = live(conn, ~p"/dashboard")
    assert dashboard_html =~ "Upcoming qualifying value bets"
  end

  test "captured odds are shown when recommendations are empty", %{conn: conn} do
    context = fixture_setup()
    insert_odds(context, decimal_odds: "2.35")

    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "No qualifying value bets yet."
    assert html =~ "Latest captured odds"
    assert html =~ "Home United vs Away City"
    assert html =~ "TestBook"
    assert html =~ "2.35"
  end

  test "recommendations render key values when present", %{conn: conn} do
    context = fixture_setup()

    insert_recommendation(context,
      odds: "2.65",
      ev_percentage: "18.75",
      recommended_stake: "12.34",
      confidence_score: "0.91"
    )

    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Home United vs Away City"
    assert html =~ "Premier Test League"
    assert html =~ "Match Winner"
    assert html =~ "TestBook"
    assert html =~ "2.65"
    assert html =~ "18.75%"
    assert html =~ "12.34"
    assert html =~ "Confidence 91 / 100"
    refute html =~ "Latest captured odds"
  end

  test "odds are grouped by fixture in latest captured odds", %{conn: conn} do
    first = fixture_setup(home_team_name: "North FC", away_team_name: "South FC")
    second = fixture_setup(home_team_name: "East FC", away_team_name: "West FC")
    insert_odds(first, decimal_odds: "1.80")
    insert_odds(first, selection_id: first.away_selection.id, decimal_odds: "4.20")
    insert_odds(second, decimal_odds: "2.05")

    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "North FC vs South FC"
    assert html =~ "East FC vs West FC"
    assert html =~ "1.80"
    assert html =~ "4.20"
    assert html =~ "2.05"
  end

  test "empty state renders when no recommendations or odds exist", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "No qualifying value bets yet."
    assert html =~ "Odds ingestion has not produced visible data yet."
    refute html =~ "Latest captured odds"
  end
end

defmodule PredictorWeb.FixtureLiveTest do
  use PredictorWeb.ConnCase

  test "/fixtures/:id loads, renders fixture data, and marks best odds", %{conn: conn} do
    context = fixture_setup()
    insert_odds(context, bookmaker_id: context.bookmaker.id, decimal_odds: "2.10")
    insert_odds(context, bookmaker_id: context.other_bookmaker.id, decimal_odds: "2.45")

    insert_recommendation(context,
      odds: "2.45",
      ev_percentage: "12.00",
      recommended_stake: "10.00"
    )

    {:ok, _view, html} = live(conn, ~p"/fixtures/#{context.fixture.id}")

    assert html =~ "Home United vs Away City"
    assert html =~ "Premier Test League"
    assert html =~ "scheduled"
    assert html =~ "Odds history by bookmaker"
    assert html =~ "TestBook"
    assert html =~ "SharpBook"
    assert html =~ "2.10"
    assert html =~ "2.45"
    assert html =~ "Recommendation history"
    assert html =~ "12.00%"
    assert html =~ "bg-emerald-100 text-emerald-800"
  end
end

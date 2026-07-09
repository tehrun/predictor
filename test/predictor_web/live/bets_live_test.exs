defmodule PredictorWeb.BetsLiveTest do
  use PredictorWeb.ConnCase

  test "/bets loads and renders tracked bet data", %{conn: conn} do
    context = fixture_setup()

    insert_bet(context,
      stake: "40.00",
      odds_taken: "2.50",
      profit_loss: "60.00",
      clv_percentage: "7.25"
    )

    {:ok, _view, html} = live(conn, ~p"/bets")

    assert html =~ "Tracked accepted bets"
    assert html =~ "Home United vs Away City"
    assert html =~ "Match Winner"
    assert html =~ "TestBook"
    assert html =~ "40.00"
    assert html =~ "2.50"
    assert html =~ "+60.00"
    assert html =~ "7.25%"
    assert html =~ "won"
  end
end

defmodule PredictorWeb.LayoutNavigationTest do
  use PredictorWeb.ConnCase

  test "dashboard nav is active on dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ ~s(aria-current="page">Dashboard)
    refute html =~ ~s(aria-current="page">Bets)
    refute html =~ ~s(aria-current="page">Scanner settings)
  end

  test "bets nav is active on bets", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/bets")

    assert html =~ ~s(aria-current="page">Bets)
    refute html =~ ~s(aria-current="page">Dashboard)
  end

  test "scanner settings nav is active on scanner settings", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/settings/scanner")

    assert html =~ ~s(aria-current="page">Scanner settings)
    refute html =~ ~s(aria-current="page">Dashboard)
  end
end

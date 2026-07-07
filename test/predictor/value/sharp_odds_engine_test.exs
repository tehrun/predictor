defmodule Predictor.Value.SharpOddsEngineTest do
  use ExUnit.Case, async: true

  alias Predictor.Value.SharpOddsEngine

  describe "calculate_fair_odds/1" do
    test "removes margin from 1X2 odds deterministically" do
      odds = [
        %{selection_id: 1, decimal_odds: Decimal.new("2.15")},
        %{selection_id: 2, decimal_odds: Decimal.new("3.40")},
        %{selection_id: 3, decimal_odds: Decimal.new("3.70")}
      ]

      fair_odds = SharpOddsEngine.calculate_fair_odds(odds)

      assert Enum.map(fair_odds, & &1.selection_id) == [1, 2, 3]

      assert_decimal(
        fair_odds |> Enum.at(0) |> Map.fetch!(:raw_implied_probability),
        "0.465116",
        6
      )

      assert_decimal(
        fair_odds |> Enum.at(1) |> Map.fetch!(:raw_implied_probability),
        "0.294118",
        6
      )

      assert_decimal(
        fair_odds |> Enum.at(2) |> Map.fetch!(:raw_implied_probability),
        "0.270270",
        6
      )

      assert_decimal(fair_odds |> Enum.at(0) |> Map.fetch!(:fair_probability), "0.451787", 6)
      assert_decimal(fair_odds |> Enum.at(1) |> Map.fetch!(:fair_probability), "0.285689", 6)
      assert_decimal(fair_odds |> Enum.at(2) |> Map.fetch!(:fair_probability), "0.262525", 6)

      assert_decimal(fair_odds |> Enum.at(0) |> Map.fetch!(:fair_odds), "2.2134", 4)
      assert_decimal(fair_odds |> Enum.at(1) |> Map.fetch!(:fair_odds), "3.5003", 4)
      assert_decimal(fair_odds |> Enum.at(2) |> Map.fetch!(:fair_odds), "3.8092", 4)
    end
  end

  defp assert_decimal(actual, expected, places) do
    assert actual |> Decimal.round(places) |> Decimal.equal?(Decimal.new(expected))
  end
end

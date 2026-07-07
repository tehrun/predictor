defmodule Predictor.Bankroll.KellyTest do
  use ExUnit.Case, async: true

  alias Predictor.Bankroll.Kelly

  describe "raw_percentage/2" do
    test "calculates full Kelly for decimal odds" do
      assert_decimal(Kelly.raw_percentage("2.50", "0.50"), "0.166667", 6)
    end

    test "returns zero when there is no positive edge" do
      assert Decimal.equal?(Kelly.raw_percentage("2.00", "0.40"), Decimal.new("0"))
    end
  end

  describe "recommend/5" do
    test "uses conservative quarter Kelly by default and recommends stake only" do
      recommendation = Kelly.recommend("1000", "2.50", "0.50")

      assert_decimal(recommendation.raw_kelly_percentage, "0.166667", 6)
      assert_decimal(recommendation.fractional_kelly_percentage, "0.041667", 6)
      assert_decimal(recommendation.recommended_stake, "41.666667", 6)
    end

    test "uses a configured Kelly fraction" do
      recommendation = Kelly.recommend("1000", "2.50", "0.50", "0.50")

      assert_decimal(recommendation.fractional_kelly_percentage, "0.083333", 6)
      assert_decimal(recommendation.recommended_stake, "83.333333", 6)
    end

    test "caps the stake as a percentage of bankroll" do
      recommendation =
        Kelly.recommend("1000", "2.50", "0.50", "0.50", max_stake_percentage: "0.05")

      assert Decimal.equal?(recommendation.recommended_stake, Decimal.new("50.00"))
    end

    test "zeros recommendations below the minimum stake threshold" do
      recommendation = Kelly.recommend("1000", "2.50", "0.50", "0.25", minimum_stake: "50")

      assert Decimal.equal?(recommendation.recommended_stake, Decimal.new("0"))
    end

    test "applies bookmaker and league exposure limits" do
      recommendation =
        Kelly.recommend("1000", "2.50", "0.50", "1.0",
          bookmaker_exposure: "90",
          bookmaker_exposure_limit_percentage: "0.10",
          league_exposure: "40",
          league_exposure_limit_percentage: "0.20"
        )

      assert Decimal.equal?(recommendation.recommended_stake, Decimal.new("10.00"))
    end
  end

  defp assert_decimal(actual, expected, places) do
    assert actual |> Decimal.round(places) |> Decimal.equal?(Decimal.new(expected))
  end
end

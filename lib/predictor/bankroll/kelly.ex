defmodule Predictor.Bankroll.Kelly do
  @moduledoc """
  Kelly and fractional Kelly staking helpers.

  This module only recommends stake sizes. It does not place bets or call any
  bookmaker APIs.
  """

  @default_kelly_fraction Decimal.new("0.25")
  @default_max_stake_percentage Decimal.new("1.0")
  @default_minimum_stake Decimal.new("0")
  @zero Decimal.new("0")

  @doc """
  Returns the full Kelly fraction for decimal odds.

  The full Kelly formula for decimal odds is:

      (decimal_odds * estimated_probability - 1) / (decimal_odds - 1)

  Negative Kelly values are returned as zero because no stake is recommended
  when the bettor has no edge.
  """
  def raw_percentage(decimal_odds, estimated_probability) do
    odds = decimal_value(decimal_odds)
    probability = decimal_value(estimated_probability)

    if Decimal.compare(odds, Decimal.new("1")) == :gt and between_zero_and_one?(probability) do
      odds
      |> Decimal.mult(probability)
      |> Decimal.sub(Decimal.new("1"))
      |> Decimal.div(Decimal.sub(odds, Decimal.new("1")))
      |> max_zero()
    else
      @zero
    end
  end

  @doc """
  Backwards-compatible helper returning the fractional Kelly percentage.

  Prefer `recommend/4` when a bankroll and stake constraints are available.
  """
  def fraction(decimal_odds, probability, multiplier \\ 1.0) do
    decimal_odds
    |> raw_percentage(probability)
    |> Decimal.mult(decimal_value(multiplier))
    |> max_zero()
    |> Decimal.to_float()
  end

  @doc """
  Recommends a stake using full Kelly, fractional Kelly, caps, and thresholds.

  Options:

    * `:max_stake_percentage` - cap as a percentage of bankroll. Defaults to `1.0` (100%).
    * `:minimum_stake` - minimum stake threshold. Defaults to `0`.
    * `:bookmaker_exposure` - current stake exposure at the bookmaker. Defaults to `0`.
    * `:bookmaker_exposure_limit_percentage` - optional bookmaker cap as percentage of bankroll.
    * `:league_exposure` - current stake exposure for the league. Defaults to `0`.
    * `:league_exposure_limit_percentage` - optional league cap as percentage of bankroll.

  Percentages are represented as decimal fractions, so `0.25` means 25%.
  """
  def recommend(
        bankroll,
        decimal_odds,
        estimated_probability,
        kelly_fraction \\ @default_kelly_fraction,
        opts \\ []
      ) do
    bankroll = decimal_value(bankroll)
    kelly_fraction = decimal_value(kelly_fraction)
    raw_percentage = raw_percentage(decimal_odds, estimated_probability)
    fractional_percentage = raw_percentage |> Decimal.mult(kelly_fraction) |> max_zero()

    recommended_stake =
      bankroll
      |> Decimal.mult(fractional_percentage)
      |> cap_stake(
        bankroll,
        Keyword.get(opts, :max_stake_percentage, @default_max_stake_percentage)
      )
      |> cap_exposure(bankroll, opts, :bookmaker_exposure, :bookmaker_exposure_limit_percentage)
      |> cap_exposure(bankroll, opts, :league_exposure, :league_exposure_limit_percentage)
      |> apply_minimum_stake(Keyword.get(opts, :minimum_stake, @default_minimum_stake))
      |> max_zero()

    %{
      raw_kelly_percentage: raw_percentage,
      fractional_kelly_percentage: fractional_percentage,
      recommended_stake: recommended_stake
    }
  end

  defp cap_stake(stake, bankroll, max_stake_percentage) do
    cap = Decimal.mult(bankroll, decimal_value(max_stake_percentage))
    decimal_min(stake, cap)
  end

  defp cap_exposure(stake, bankroll, opts, exposure_key, limit_key) do
    case Keyword.fetch(opts, limit_key) do
      :error ->
        stake

      {:ok, exposure_limit_percentage} ->
        current_exposure = opts |> Keyword.get(exposure_key, @zero) |> decimal_value()
        limit = Decimal.mult(bankroll, decimal_value(exposure_limit_percentage))
        remaining = limit |> Decimal.sub(current_exposure) |> max_zero()

        decimal_min(stake, remaining)
    end
  end

  defp apply_minimum_stake(stake, minimum_stake) do
    minimum_stake = decimal_value(minimum_stake)

    if Decimal.compare(stake, minimum_stake) == :lt do
      @zero
    else
      stake
    end
  end

  defp decimal_min(left, right) do
    case Decimal.compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  defp max_zero(value) do
    case Decimal.compare(value, @zero) do
      :lt -> @zero
      _ -> value
    end
  end

  defp between_zero_and_one?(value) do
    Decimal.compare(value, @zero) != :lt and Decimal.compare(value, Decimal.new("1")) != :gt
  end

  defp decimal_value(%Decimal{} = value), do: value
  defp decimal_value(value), do: Decimal.new(to_string(value))
end

defmodule Predictor.Bankroll.Kelly do
  @moduledoc "Kelly and fractional Kelly staking helpers."

  def fraction(decimal_odds, probability, multiplier \\ 1.0) do
    b = decimal_odds - 1
    max((b * probability - (1 - probability)) / b, 0) * multiplier
  end
end

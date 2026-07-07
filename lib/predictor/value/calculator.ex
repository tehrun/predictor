defmodule Predictor.Value.Calculator do
  @moduledoc "Calculates fair odds and expected value."

  def expected_value(decimal_odds, probability) when decimal_odds > 0 and probability >= 0 do
    decimal_odds * probability - 1
  end
end

defmodule Predictor.Odds.Normalizer do
  @moduledoc "Normalizes sportsbook odds payloads into Predictor's internal shape."

  def normalize_market(%{} = market), do: market
end

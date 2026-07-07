defmodule Predictor.Arbitrage.Detector do
  @moduledoc "Detects arbitrage opportunities across normalized odds."

  def arbitrage?(probabilities) when is_list(probabilities), do: Enum.sum(probabilities) < 1
end

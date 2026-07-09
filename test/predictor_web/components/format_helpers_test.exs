defmodule PredictorWeb.FormatHelpersTest do
  use ExUnit.Case, async: true
  alias PredictorWeb.FormatHelpers

  test "formats betting percentages, odds, currency, and confidence labels" do
    assert FormatHelpers.odds(Decimal.new("2.345")) == "2.35"
    assert FormatHelpers.ev(Decimal.new("8.4")) == "+8.40% EV"
    assert FormatHelpers.currency(Decimal.new("120")) == "+120.00 DKK"
    assert FormatHelpers.profit(Decimal.new("-50")) == "-50.00 DKK"
    assert FormatHelpers.confidence_label(Decimal.new("0.86")) == "Very high"
    assert FormatHelpers.confidence_label(Decimal.new("0.52")) == "Medium"
  end
end

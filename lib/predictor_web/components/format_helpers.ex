defmodule PredictorWeb.FormatHelpers do
  @moduledoc "Presentation formatting helpers for betting UI."

  def dash(nil), do: "—"
  def decimal(nil), do: "—"
  def decimal(%Decimal{} = d), do: d |> Decimal.round(2) |> Decimal.to_string(:normal)
  def decimal(v) when is_number(v), do: :erlang.float_to_binary(v / 1, decimals: 2)

  def odds(v), do: decimal(v)
  def currency(nil), do: "—"
  def currency(%Decimal{} = d), do: "#{signed_decimal(d)} DKK"
  def currency(v), do: "#{v} DKK"

  def profit(nil), do: "—"
  def profit(%Decimal{} = d), do: "#{signed_decimal(d)} DKK"

  def percent(nil), do: "—"
  def percent(%Decimal{} = d), do: "#{decimal(d)}%"
  def probability(nil), do: "—"

  def probability(%Decimal{} = d),
    do: "#{d |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_string(:normal)}%"

  def ev(nil), do: "—"
  def ev(%Decimal{} = d), do: "#{signed_decimal(d)}% EV"

  def confidence_label(nil), do: "Unknown"

  def confidence_label(%Decimal{} = d) do
    cond do
      Decimal.compare(d, Decimal.new("0.85")) != :lt -> "Very high"
      Decimal.compare(d, Decimal.new("0.70")) != :lt -> "High"
      Decimal.compare(d, Decimal.new("0.50")) != :lt -> "Medium"
      true -> "Low"
    end
  end

  def datetime(nil), do: "—"
  def datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y %H:%M UTC")
  def short_datetime(nil), do: "—"
  def short_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %H:%M UTC")

  def relative(nil), do: "—"

  def relative(%DateTime{} = dt) do
    seconds = DateTime.diff(dt, DateTime.utc_now(), :second)
    abs = abs(seconds)
    h = div(abs, 3600)
    m = div(rem(abs, 3600), 60)
    text = if h > 0, do: "#{h}h #{m}m", else: "#{m}m"
    if seconds >= 0, do: "Starts in #{text}", else: "Started #{text} ago"
  end

  defp signed_decimal(%Decimal{} = d) do
    sign = if Decimal.compare(d, 0) == :gt, do: "+", else: ""
    sign <> decimal(d)
  end
end

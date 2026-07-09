defmodule Predictor.Scanner.Config do
  @moduledoc """
  Runtime configuration for scanner behavior.

  This module is the MVP configuration layer for odds scanning. Values are loaded
  from application/runtime config so deployments can tune scanner behavior with
  environment variables. If settings need to be edited from the dashboard later,
  this module can become the boundary that reads from a `scanner_settings` table.
  """

  @default_sharp_reference_source "pinnacle"
  @default_minimum_ev_threshold Decimal.new("0.05")
  @default_minimum_confidence_threshold Decimal.new("0.50")
  @default_minimum_odds nil
  @default_maximum_odds nil
  @default_kelly_fraction Decimal.new("0.25")
  @default_max_stake_percentage Decimal.new("0.01")
  @default_telegram_alert_threshold Decimal.new("0.05")
  @default_odds_collection_frequency_seconds 300

  @type t :: %__MODULE__{
          enabled_sports: [String.t()],
          enabled_leagues: [String.t()],
          enabled_markets: [String.t()],
          enabled_bookmakers: [String.t()],
          sharp_reference_source: String.t(),
          minimum_ev_threshold: Decimal.t(),
          minimum_confidence_threshold: Decimal.t(),
          minimum_odds: Decimal.t() | nil,
          maximum_odds: Decimal.t() | nil,
          kelly_fraction: Decimal.t(),
          max_stake_percentage: Decimal.t(),
          telegram_alert_threshold: Decimal.t(),
          odds_collection_frequency_seconds: pos_integer()
        }

  defstruct enabled_sports: [],
            enabled_leagues: [],
            enabled_markets: [],
            enabled_bookmakers: [],
            sharp_reference_source: @default_sharp_reference_source,
            minimum_ev_threshold: @default_minimum_ev_threshold,
            minimum_confidence_threshold: @default_minimum_confidence_threshold,
            minimum_odds: @default_minimum_odds,
            maximum_odds: @default_maximum_odds,
            kelly_fraction: @default_kelly_fraction,
            max_stake_percentage: @default_max_stake_percentage,
            telegram_alert_threshold: @default_telegram_alert_threshold,
            odds_collection_frequency_seconds: @default_odds_collection_frequency_seconds

  @doc "Loads scanner settings from application config."
  def load do
    config = Application.get_env(:predictor, :scanner, [])

    %__MODULE__{
      enabled_sports: list(config, :enabled_sports),
      enabled_leagues: list(config, :enabled_leagues),
      enabled_markets: list(config, :enabled_markets),
      enabled_bookmakers: list(config, :enabled_bookmakers),
      sharp_reference_source:
        string(config, :sharp_reference_source, @default_sharp_reference_source),
      minimum_ev_threshold: decimal(config, :minimum_ev_threshold, @default_minimum_ev_threshold),
      minimum_confidence_threshold:
        decimal(config, :minimum_confidence_threshold, @default_minimum_confidence_threshold),
      minimum_odds: optional_decimal(config, :minimum_odds, @default_minimum_odds),
      maximum_odds: optional_decimal(config, :maximum_odds, @default_maximum_odds),
      kelly_fraction: decimal(config, :kelly_fraction, @default_kelly_fraction),
      max_stake_percentage: decimal(config, :max_stake_percentage, @default_max_stake_percentage),
      telegram_alert_threshold:
        decimal(config, :telegram_alert_threshold, @default_telegram_alert_threshold),
      odds_collection_frequency_seconds:
        positive_integer(
          config,
          :odds_collection_frequency_seconds,
          @default_odds_collection_frequency_seconds
        )
    }
  end

  @doc "Returns true when a slug/id is allowed by the configured list; empty means all are allowed."
  def enabled?(_configured, nil), do: true
  def enabled?([], _value), do: true
  def enabled?(configured, value), do: normalize(value) in configured

  @doc "Options used by the value recommendation engine."
  def recommendation_opts(%__MODULE__{} = config) do
    [
      minimum_ev: config.minimum_ev_threshold,
      minimum_odds: config.minimum_odds,
      maximum_odds: config.maximum_odds,
      confidence_score: config.minimum_confidence_threshold
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp list(config, key) do
    config
    |> Keyword.get(key, [])
    |> List.wrap()
    |> Enum.flat_map(fn
      value when is_binary(value) -> String.split(value, ",")
      value -> [value]
    end)
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp string(config, key, default), do: config |> Keyword.get(key, default) |> to_string()

  defp decimal(config, key, default), do: config |> Keyword.get(key, default) |> decimal_value()

  defp optional_decimal(config, key, default) do
    case Keyword.get(config, key, default) do
      value when value in [nil, ""] -> nil
      value -> decimal_value(value)
    end
  end

  defp positive_integer(config, key, default) do
    case config |> Keyword.get(key, default) |> integer_value() do
      value when value > 0 -> value
      _ -> default
    end
  end

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(value), do: value |> to_string() |> String.to_integer()

  defp decimal_value(%Decimal{} = value), do: value
  defp decimal_value(value), do: Decimal.new(to_string(value))

  defp normalize(value), do: value |> to_string() |> String.trim() |> String.downcase()
end

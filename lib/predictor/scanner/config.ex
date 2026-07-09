defmodule Predictor.Scanner.Config do
  import Ecto.Query

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

  alias Predictor.Repo
  alias Predictor.Scanner.Setting

  @doc "Loads scanner settings from the persisted singleton row, falling back to runtime env config."
  def load do
    config = persisted_config() || Application.get_env(:predictor, :scanner, [])

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

  @doc "Returns the editable singleton scanner setting, seeded from runtime config when absent."
  def get_setting do
    case Repo.get_by(Setting, singleton_key: Setting.singleton_key()) do
      nil -> struct_from_config(Application.get_env(:predictor, :scanner, []))
      setting -> setting
    end
  rescue
    _error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      struct_from_config(Application.get_env(:predictor, :scanner, []))
  end

  @doc "Returns a scanner setting changeset for forms."
  def change_setting(%Setting{} = setting, attrs \\ %{}), do: Setting.changeset(setting, attrs)

  @doc "Creates or updates the singleton scanner setting."
  def save_setting(attrs) do
    existing =
      Repo.get_by(Setting, singleton_key: Setting.singleton_key()) ||
        struct_from_config(Application.get_env(:predictor, :scanner, []))

    existing
    |> Setting.changeset(attrs)
    |> Repo.insert_or_update()
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

  defp persisted_config do
    if repo_started?() and table_exists?() do
      Setting
      |> where([s], s.singleton_key == ^Setting.singleton_key())
      |> limit(1)
      |> Repo.one()
      |> case do
        nil -> nil
        setting -> Setting.to_config(setting)
      end
    end
  rescue
    _error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] -> nil
  end

  defp repo_started?, do: Process.whereis(Repo) != nil

  defp table_exists? do
    %{rows: [[exists]]} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "select to_regclass('public.scanner_settings') is not null",
        []
      )

    exists
  end

  defp struct_from_config(config) do
    %Setting{}
    |> Setting.changeset(%{
      enabled_sports: Keyword.get(config, :enabled_sports, ""),
      enabled_leagues: Keyword.get(config, :enabled_leagues, ""),
      enabled_markets: Keyword.get(config, :enabled_markets, ""),
      enabled_bookmakers: Keyword.get(config, :enabled_bookmakers, ""),
      sharp_reference_source:
        Keyword.get(config, :sharp_reference_source, @default_sharp_reference_source),
      minimum_ev_threshold:
        Keyword.get(config, :minimum_ev_threshold, @default_minimum_ev_threshold),
      minimum_confidence_threshold:
        Keyword.get(config, :minimum_confidence_threshold, @default_minimum_confidence_threshold),
      minimum_odds: Keyword.get(config, :minimum_odds, @default_minimum_odds),
      maximum_odds: Keyword.get(config, :maximum_odds, @default_maximum_odds),
      kelly_fraction: Keyword.get(config, :kelly_fraction, @default_kelly_fraction),
      max_stake_percentage:
        Keyword.get(config, :max_stake_percentage, @default_max_stake_percentage),
      telegram_alert_threshold:
        Keyword.get(config, :telegram_alert_threshold, @default_telegram_alert_threshold),
      odds_collection_frequency_seconds:
        Keyword.get(
          config,
          :odds_collection_frequency_seconds,
          @default_odds_collection_frequency_seconds
        )
    })
    |> Ecto.Changeset.apply_changes()
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

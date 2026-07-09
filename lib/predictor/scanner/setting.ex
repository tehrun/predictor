defmodule Predictor.Scanner.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Persisted singleton scanner configuration editable from the dashboard.

  Blank enabled-list fields mean all values are allowed, matching `Predictor.Scanner.Config`.
  """

  @singleton_key "default"

  schema "scanner_settings" do
    field(:singleton_key, :string, default: @singleton_key)
    field(:enabled_sports, :string, default: "")
    field(:enabled_leagues, :string, default: "")
    field(:enabled_markets, :string, default: "")
    field(:enabled_bookmakers, :string, default: "")
    field(:sharp_reference_source, :string, default: "pinnacle")
    field(:minimum_ev_threshold, :decimal, default: Decimal.new("0.05"))
    field(:minimum_confidence_threshold, :decimal, default: Decimal.new("0.50"))
    field(:minimum_odds, :decimal)
    field(:maximum_odds, :decimal)
    field(:kelly_fraction, :decimal, default: Decimal.new("0.25"))
    field(:max_stake_percentage, :decimal, default: Decimal.new("0.01"))
    field(:telegram_alert_threshold, :decimal, default: Decimal.new("0.05"))
    field(:odds_collection_frequency_seconds, :integer, default: 300)

    timestamps(type: :utc_datetime)
  end

  def singleton_key, do: @singleton_key

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :enabled_sports,
      :enabled_leagues,
      :enabled_markets,
      :enabled_bookmakers,
      :sharp_reference_source,
      :minimum_ev_threshold,
      :minimum_confidence_threshold,
      :minimum_odds,
      :maximum_odds,
      :kelly_fraction,
      :max_stake_percentage,
      :telegram_alert_threshold,
      :odds_collection_frequency_seconds
    ])
    |> put_change(:singleton_key, @singleton_key)
    |> normalize_blank_strings()
    |> validate_required([
      :singleton_key,
      :sharp_reference_source,
      :minimum_ev_threshold,
      :minimum_confidence_threshold,
      :kelly_fraction,
      :max_stake_percentage,
      :telegram_alert_threshold,
      :odds_collection_frequency_seconds
    ])
    |> validate_length(:sharp_reference_source, min: 1, max: 100)
    |> validate_number(:minimum_ev_threshold, greater_than_or_equal_to: 0)
    |> validate_number(:minimum_confidence_threshold,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_number(:minimum_odds, greater_than: 1)
    |> validate_number(:maximum_odds, greater_than: 1)
    |> validate_number(:kelly_fraction, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:max_stake_percentage, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:telegram_alert_threshold, greater_than_or_equal_to: 0)
    |> validate_number(:odds_collection_frequency_seconds, greater_than: 0)
    |> validate_odds_bounds()
    |> unique_constraint(:singleton_key)
  end

  def to_config(setting) do
    [
      enabled_sports: setting.enabled_sports || "",
      enabled_leagues: setting.enabled_leagues || "",
      enabled_markets: setting.enabled_markets || "",
      enabled_bookmakers: setting.enabled_bookmakers || "",
      sharp_reference_source: setting.sharp_reference_source,
      minimum_ev_threshold: setting.minimum_ev_threshold,
      minimum_confidence_threshold: setting.minimum_confidence_threshold,
      minimum_odds: setting.minimum_odds,
      maximum_odds: setting.maximum_odds,
      kelly_fraction: setting.kelly_fraction,
      max_stake_percentage: setting.max_stake_percentage,
      telegram_alert_threshold: setting.telegram_alert_threshold,
      odds_collection_frequency_seconds: setting.odds_collection_frequency_seconds
    ]
  end

  defp normalize_blank_strings(changeset) do
    Enum.reduce([:minimum_odds, :maximum_odds], changeset, fn field, acc ->
      case get_change(acc, field) do
        "" -> put_change(acc, field, nil)
        _ -> acc
      end
    end)
  end

  defp validate_odds_bounds(changeset) do
    minimum = get_field(changeset, :minimum_odds)
    maximum = get_field(changeset, :maximum_odds)

    if minimum && maximum && Decimal.compare(minimum, maximum) == :gt do
      add_error(changeset, :maximum_odds, "must be greater than or equal to minimum odds")
    else
      changeset
    end
  end
end

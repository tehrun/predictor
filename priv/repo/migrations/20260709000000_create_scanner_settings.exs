defmodule Predictor.Repo.Migrations.CreateScannerSettings do
  use Ecto.Migration

  def change do
    create table(:scanner_settings) do
      add(:singleton_key, :text, null: false, default: "default")
      add(:enabled_sports, :text, null: false, default: "")
      add(:enabled_leagues, :text, null: false, default: "")
      add(:enabled_markets, :text, null: false, default: "")
      add(:enabled_bookmakers, :text, null: false, default: "")
      add(:sharp_reference_source, :text, null: false, default: "pinnacle")
      add(:minimum_ev_threshold, :decimal, null: false, default: 0.05)
      add(:minimum_confidence_threshold, :decimal, null: false, default: 0.50)
      add(:minimum_odds, :decimal)
      add(:maximum_odds, :decimal)
      add(:kelly_fraction, :decimal, null: false, default: 0.25)
      add(:max_stake_percentage, :decimal, null: false, default: 0.01)
      add(:telegram_alert_threshold, :decimal, null: false, default: 0.05)
      add(:odds_collection_frequency_seconds, :integer, null: false, default: 300)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:scanner_settings, [:singleton_key]))
  end
end

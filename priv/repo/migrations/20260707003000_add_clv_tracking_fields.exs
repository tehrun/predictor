defmodule Predictor.Repo.Migrations.AddClvTrackingFields do
  use Ecto.Migration

  def change do
    alter table(:value_recommendations) do
      add(:closing_odds, :decimal, precision: 12, scale: 4)
      add(:clv_decimal_odds, :decimal, precision: 12, scale: 4)
      add(:clv_implied_probability, :decimal, precision: 10, scale: 6)
      add(:clv_percentage, :decimal, precision: 10, scale: 4)
    end

    alter table(:bets) do
      add(:clv_decimal_odds, :decimal, precision: 12, scale: 4)
      add(:clv_implied_probability, :decimal, precision: 10, scale: 6)
      add(:clv_percentage, :decimal, precision: 10, scale: 4)
    end

    create(index(:value_recommendations, [:clv_decimal_odds]))
    create(index(:bets, [:clv_decimal_odds]))
  end
end
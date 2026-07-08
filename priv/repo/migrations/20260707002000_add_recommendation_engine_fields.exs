defmodule Predictor.Repo.Migrations.AddRecommendationEngineFields do
  use Ecto.Migration

  def change do
    alter table(:value_recommendations) do
      add(:odds, :decimal, precision: 12, scale: 4)
      add(:fair_probability, :decimal, precision: 8, scale: 6)
      add(:fair_odds, :decimal, precision: 12, scale: 4)
      add(:ev, :decimal, precision: 10, scale: 6)

      modify(:status, :string,
        null: false,
        default: "new",
        from: {:string, null: false, default: "open"}
      )
    end

    execute(
      "UPDATE value_recommendations SET status = 'new' WHERE status = 'open'",
      "UPDATE value_recommendations SET status = 'open' WHERE status = 'new'"
    )

    create(
      unique_index(
        :value_recommendations,
        [:fixture_id, :bookmaker_id, :market_id, :selection_id],
        name: :value_recommendations_current_position_index
      )
    )
  end
end

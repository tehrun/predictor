defmodule Predictor.Repo.Migrations.AddRealMoneyGuardrails do
  use Ecto.Migration

  def change do
    create table(:bankroll_configs) do
      add(:user_label, :string)
      add(:bankroll_amount, :decimal, precision: 12, scale: 2, null: false)
      add(:currency, :string, null: false, default: "USD")
      add(:daily_stake_limit, :decimal, precision: 12, scale: 2, null: false)
      add(:weekly_stake_limit, :decimal, precision: 12, scale: 2, null: false)
      add(:monthly_stake_limit, :decimal, precision: 12, scale: 2, null: false)
      add(:per_bet_stake_cap, :decimal, precision: 12, scale: 2, null: false)
      add(:cooldown_after_loss_count, :integer, null: false, default: 0)
      add(:cooldown_period_minutes, :integer, null: false, default: 0)
      add(:informational_only_acknowledged, :boolean, null: false, default: false)
      add(:positive_clv_required, :boolean, null: false, default: true)
      add(:provider_terms_reviewed_at, :utc_datetime)
      add(:provider_terms_review_notes, :text)
      add(:jurisdiction_legal_reviewed_at, :utc_datetime)
      add(:jurisdiction_legal_review_notes, :text)
      add(:bet_placement_automation_enabled, :boolean, null: false, default: false)

      timestamps(type: :utc_datetime)
    end

    create table(:recommendation_audit_logs) do
      add(:event_type, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)
      add(:actor, :string)
      add(:details, :map, null: false, default: %{})
      add(:value_recommendation_id, references(:value_recommendations, on_delete: :nilify_all))
      add(:bet_id, references(:bets, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create index(:recommendation_audit_logs, [:event_type, :occurred_at])
    create index(:recommendation_audit_logs, [:value_recommendation_id])
    create index(:recommendation_audit_logs, [:bet_id])
  end
end

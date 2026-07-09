defmodule Predictor.Guardrails.BankrollConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Explicit bankroll and staking guardrail configuration.

  A configuration is invalid until a user supplies a bankroll amount and confirms
  that recommendations are informational only. These limits are intended to cap
  recommendation sizing; they do not authorize automated bet placement.
  """

  schema "bankroll_configs" do
    field(:user_label, :string)
    field(:bankroll_amount, :decimal)
    field(:currency, :string, default: "USD")
    field(:daily_stake_limit, :decimal)
    field(:weekly_stake_limit, :decimal)
    field(:monthly_stake_limit, :decimal)
    field(:per_bet_stake_cap, :decimal)
    field(:cooldown_after_loss_count, :integer, default: 0)
    field(:cooldown_period_minutes, :integer, default: 0)
    field(:informational_only_acknowledged, :boolean, default: false)
    field(:positive_clv_required, :boolean, default: true)
    field(:provider_terms_reviewed_at, :utc_datetime)
    field(:provider_terms_review_notes, :string)
    field(:jurisdiction_legal_reviewed_at, :utc_datetime)
    field(:jurisdiction_legal_review_notes, :string)
    field(:bet_placement_automation_enabled, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [
      :user_label,
      :bankroll_amount,
      :currency,
      :daily_stake_limit,
      :weekly_stake_limit,
      :monthly_stake_limit,
      :per_bet_stake_cap,
      :cooldown_after_loss_count,
      :cooldown_period_minutes,
      :informational_only_acknowledged,
      :positive_clv_required,
      :provider_terms_reviewed_at,
      :provider_terms_review_notes,
      :jurisdiction_legal_reviewed_at,
      :jurisdiction_legal_review_notes,
      :bet_placement_automation_enabled
    ])
    |> validate_required([
      :bankroll_amount,
      :currency,
      :daily_stake_limit,
      :weekly_stake_limit,
      :monthly_stake_limit,
      :per_bet_stake_cap
    ])
    |> validate_number(:bankroll_amount, greater_than: 0)
    |> validate_number(:daily_stake_limit, greater_than_or_equal_to: 0)
    |> validate_number(:weekly_stake_limit, greater_than_or_equal_to: 0)
    |> validate_number(:monthly_stake_limit, greater_than_or_equal_to: 0)
    |> validate_number(:per_bet_stake_cap, greater_than: 0)
    |> validate_number(:cooldown_after_loss_count, greater_than_or_equal_to: 0)
    |> validate_number(:cooldown_period_minutes, greater_than_or_equal_to: 0)
    |> validate_acceptance(:informational_only_acknowledged,
      message:
        "must be accepted because recommendations are informational and do not guarantee profit"
    )
    |> validate_automation_requirements()
  end

  defp validate_automation_requirements(changeset) do
    if get_field(changeset, :bet_placement_automation_enabled) do
      changeset
      |> validate_required([:provider_terms_reviewed_at, :jurisdiction_legal_reviewed_at])
      |> validate_change(:positive_clv_required, fn
        :positive_clv_required, true ->
          []

        :positive_clv_required, _ ->
          [positive_clv_required: "must remain enabled before bet placement automation"]
      end)
    else
      changeset
    end
  end
end

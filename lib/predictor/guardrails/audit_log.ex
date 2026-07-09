defmodule Predictor.Guardrails.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Immutable audit trail for generated recommendations and user-accepted bets.
  """

  schema "recommendation_audit_logs" do
    field(:event_type, :string)
    field(:occurred_at, :utc_datetime)
    field(:actor, :string)
    field(:details, :map, default: %{})

    belongs_to(:value_recommendation, Predictor.Value.ValueRecommendation)
    belongs_to(:bet, Predictor.Betting.Bet)

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :event_type,
      :occurred_at,
      :actor,
      :details,
      :value_recommendation_id,
      :bet_id
    ])
    |> validate_required([:event_type, :occurred_at])
    |> validate_inclusion(:event_type, ["recommendation_generated", "bet_accepted"])
    |> assoc_constraint(:value_recommendation)
    |> assoc_constraint(:bet)
  end
end

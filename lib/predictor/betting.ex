defmodule Predictor.Betting do
  @moduledoc """
  Helpers for manually accepted bets.

  This context records accepted bets and audit events only. It intentionally does
  not place bets with bookmakers or call bet-placement APIs.
  """

  alias Ecto.Multi
  alias Predictor.Betting.Bet
  alias Predictor.Guardrails.AuditLog
  alias Predictor.Repo

  def accept_bet(attrs) do
    Multi.new()
    |> Multi.insert(:bet, Bet.changeset(%Bet{}, attrs))
    |> Multi.insert(:audit_log, fn %{bet: bet} ->
      AuditLog.changeset(%AuditLog{}, %{
        event_type: "bet_accepted",
        occurred_at: bet.placed_at,
        actor: Map.get(attrs, :actor) || Map.get(attrs, "actor") || "manual_user",
        bet_id: bet.id,
        value_recommendation_id: bet.value_recommendation_id,
        details: %{
          "stake" => Decimal.to_string(bet.stake),
          "odds_taken" => Decimal.to_string(bet.odds_taken),
          "disclaimer" => "manual acceptance only; no automated bet placement"
        }
      })
    end)
    |> Repo.transaction()
  end
end

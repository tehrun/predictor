defmodule Predictor.Odds.ClosingLineTrackerWorker do
  @moduledoc """
  Captures the final available odds before kickoff and updates CLV metrics.
  """

  use Oban.Worker, queue: :odds, max_attempts: 5

  require Logger

  alias Predictor.Odds

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with {:ok, fixture_id} <- fetch_id(args, "fixture_id"),
         {:ok, bookmaker_id} <- fetch_id(args, "bookmaker_id"),
         {:ok, market_id} <- fetch_id(args, "market_id"),
         {:ok, selection_id} <- fetch_id(args, "selection_id") do
      case Odds.capture_closing_line_for_position(
             fixture_id,
             bookmaker_id,
             market_id,
             selection_id
           ) do
        {:ok, _closing_line} ->
          :ok

        {:error, :closing_odds_not_found} ->
          Logger.warning(
            "Closing odds not found for fixture=#{fixture_id} bookmaker=#{bookmaker_id} market=#{market_id} selection=#{selection_id}"
          )

          {:snooze, 60}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_id(args, key) do
    case Map.fetch(args, key) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} when is_binary(value) -> parse_integer(value)
      :error -> {:error, {:missing_arg, key}}
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> {:error, {:invalid_id, value}}
    end
  end
end
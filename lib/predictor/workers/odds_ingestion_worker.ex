defmodule Predictor.Workers.OddsIngestionWorker do
  @moduledoc """
  Backward-compatible Oban worker for manually enqueued odds ingestion jobs.

  Older scripts may enqueue this worker name directly. Delegate to the current
  collector so those jobs actually fetch and persist odds.
  """

  use Oban.Worker, queue: :odds, max_attempts: 3

  alias Predictor.Odds.CollectOddsWorker

  @impl Oban.Worker
  def perform(%Oban.Job{} = job), do: CollectOddsWorker.perform(job)
end

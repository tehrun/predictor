defmodule Predictor.Workers.OddsIngestionWorker do
  use Oban.Worker, queue: :odds, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    :ok
  end
end

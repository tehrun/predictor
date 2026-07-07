defmodule Predictor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PredictorWeb.Telemetry,
      Predictor.Repo,
      {DNSCluster, query: Application.get_env(:predictor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Predictor.PubSub},
      {Finch, name: Predictor.Finch},
      {Oban, Application.fetch_env!(:predictor, Oban)},
      PredictorWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Predictor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PredictorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

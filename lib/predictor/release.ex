defmodule Predictor.Release do
  @moduledoc """
  Release tasks that can be run from the production release before the web server starts.
  """

  @app :predictor

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _apps, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _apps, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

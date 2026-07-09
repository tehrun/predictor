defmodule PredictorWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint PredictorWeb.Endpoint

      use PredictorWeb, :verified_routes

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import PredictorWeb.ConnCase
      import PredictorWeb.LiveFixtures
    end
  end

  setup tags do
    PredictorWeb.ConnCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Predictor.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end

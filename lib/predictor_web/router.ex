defmodule PredictorWeb.Router do
  use PredictorWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {PredictorWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", PredictorWeb do
    pipe_through(:browser)

    live("/", DashboardLive, :index)
    live("/dashboard", DashboardLive, :index)
    live("/fixtures/:id", FixtureLive, :show)
    live("/bets", BetsLive, :index)
  end

  scope "/", PredictorWeb do
    pipe_through(:api)

    get("/health", HealthController, :show)
  end

  if Application.compile_env(:predictor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: PredictorWeb.Telemetry)
    end
  end
end

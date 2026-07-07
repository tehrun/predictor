defmodule PredictorWeb.HealthController do
  use PredictorWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok", application: "predictor"})
  end
end

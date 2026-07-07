defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <section class="dashboard">
      <h1>Predictor</h1>
      <p>Live odds, value, arbitrage, bankroll, and notification workflows are ready to be connected.</p>
    </section>
    """
  end
end

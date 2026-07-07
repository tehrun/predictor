defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view

  alias Predictor.Odds

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :clv_analytics, Odds.clv_analytics())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="dashboard">
      <h1>Predictor</h1>
      <p>Live odds, value, arbitrage, bankroll, and notification workflows are ready to be connected.</p>

      <section class="clv-analytics">
        <h2>Closing-line value</h2>
        <dl>
          <dt>Tracked bets</dt>
          <dd>{@clv_analytics.tracked_bets || 0}</dd>
          <dt>Average decimal movement</dt>
          <dd>{@clv_analytics.average_decimal_clv || "—"}</dd>
          <dt>Average probability improvement</dt>
          <dd>{@clv_analytics.average_probability_clv || "—"}</dd>
          <dt>Average CLV %</dt>
          <dd>{@clv_analytics.average_percentage_clv || "—"}</dd>
          <dt>Positive CLV bets</dt>
          <dd>{@clv_analytics.positive_clv_bets || 0}</dd>
        </dl>
      </section>
    </section>
    """
  end
end

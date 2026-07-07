defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view

  import Ecto.Query

  alias Predictor.Repo
  alias Predictor.Value.ValueRecommendation

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {recommendations, dashboard_error} = todays_value_bets()

    {:ok,
     socket
     |> assign(:page_title, "Value dashboard")
     |> assign(:recommendations, recommendations)
     |> assign(:dashboard_error, dashboard_error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-7xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">Dashboard</p>
        <h1 class="text-3xl font-bold text-slate-900">Today’s qualifying value bets</h1>
        <p class="text-slate-600">
          Server-rendered LiveView table of positive expected-value opportunities that are still actionable today.
        </p>
      </header>

      <div
        :if={@dashboard_error}
        class="rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-900"
      >
        <p class="font-semibold">Dashboard data is temporarily unavailable.</p>
        <p>{@dashboard_error}</p>
      </div>

      <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
              <tr>
                <th class="px-4 py-3">Fixture</th>
                <th class="px-4 py-3">League</th>
                <th class="px-4 py-3">Market</th>
                <th class="px-4 py-3">Selection</th>
                <th class="px-4 py-3">Bookmaker</th>
                <th class="px-4 py-3 text-right">Current odds</th>
                <th class="px-4 py-3 text-right">Fair odds</th>
                <th class="px-4 py-3 text-right">EV %</th>
                <th class="px-4 py-3 text-right">Stake</th>
                <th class="px-4 py-3 text-right">Confidence</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :if={@dashboard_error}>
                <td colspan="10" class="px-4 py-8 text-center text-amber-700">
                  Value recommendations cannot be loaded until the database issue above is resolved.
                </td>
              </tr>
              <tr :if={!@dashboard_error and Enum.empty?(@recommendations)}>
                <td colspan="10" class="px-4 py-8 text-center text-slate-500">
                  No qualifying value bets found for today.
                </td>
              </tr>
              <tr :for={rec <- @recommendations} class="hover:bg-slate-50">
                <td class="whitespace-nowrap px-4 py-3 font-medium text-slate-900">
                  <.link navigate={~p"/fixtures/#{rec.fixture_id}"} class="text-emerald-700 hover:underline">
                    {fixture_name(rec.fixture)}
                  </.link>
                  <div class="text-xs font-normal text-slate-500">{format_datetime(rec.fixture.kickoff_at)}</div>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{rec.fixture.league.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{rec.market.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{rec.selection.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{rec.bookmaker.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{format_decimal(rec.odds)}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{format_decimal(rec.fair_odds)}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right text-emerald-700 font-semibold">{format_percent(rec.ev_percentage)}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{format_decimal(rec.recommended_stake)}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{format_rating(rec.confidence_score)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp todays_value_bets do
    today = Date.utc_today()
    start_of_day = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(today, ~T[23:59:59], "Etc/UTC")

    recommendations =
      from(r in ValueRecommendation,
        join: f in assoc(r, :fixture),
        where: f.kickoff_at >= ^start_of_day and f.kickoff_at <= ^end_of_day,
        where: r.status in ["new", "notified", "accepted"],
        order_by: [desc: r.ev_percentage, desc: r.confidence_score],
        preload: [
          fixture: [:league, :home_team, :away_team],
          market: [],
          selection: [],
          bookmaker: []
        ],
        limit: 100
      )
      |> Repo.all()

    {recommendations, nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Unable to load dashboard recommendations: #{Exception.message(error)}")
      {[], "Please make sure the database is reachable and migrations have been run."}
  end

  defp fixture_name(fixture), do: "#{fixture.home_team.name} vs #{fixture.away_team.name}"
  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %H:%M UTC")
  defp format_decimal(nil), do: "—"
  defp format_decimal(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  defp format_percent(nil), do: "—"
  defp format_percent(decimal), do: "#{format_decimal(decimal)}%"
  defp format_rating(nil), do: "—"

  defp format_rating(decimal),
    do: "#{decimal |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string(:normal)} / 100"
end

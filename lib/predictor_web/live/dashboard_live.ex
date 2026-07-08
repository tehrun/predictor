defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view

  import Ecto.Query

  alias Predictor.Repo
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Value.ValueRecommendation

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {recommendations, latest_odds, dashboard_error} = dashboard_data()

    {:ok,
     socket
     |> assign(:page_title, "Value dashboard")
     |> assign(:recommendations, recommendations)
     |> assign(:latest_odds, latest_odds)
     |> assign(:dashboard_error, dashboard_error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-7xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">Dashboard</p>
        <h1 class="text-3xl font-bold text-slate-900">Upcoming qualifying value bets</h1>
        <p class="text-slate-600">
          Server-rendered LiveView table of positive expected-value opportunities for upcoming fixtures.
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
                  No qualifying value bets found for upcoming fixtures yet. Run odds ingestion and the dashboard will populate once recommendations are generated.
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

      <div
        :if={!@dashboard_error and Enum.empty?(@recommendations) and !Enum.empty?(@latest_odds)}
        class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"
      >
        <div class="border-b border-slate-200 bg-slate-50 px-4 py-3">
          <h2 class="font-semibold text-slate-900">Latest captured odds</h2>
          <p class="text-sm text-slate-600">
            Odds ingestion is reaching the database. Value recommendations will appear above after fair odds are generated and pass the EV threshold.
          </p>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
              <tr>
                <th class="px-4 py-3">Fixture</th>
                <th class="px-4 py-3">League</th>
                <th class="px-4 py-3">Market</th>
                <th class="px-4 py-3">Selection</th>
                <th class="px-4 py-3">Bookmaker</th>
                <th class="px-4 py-3 text-right">Odds</th>
                <th class="px-4 py-3 text-right">Captured</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={odds <- @latest_odds} class="hover:bg-slate-50">
                <td class="whitespace-nowrap px-4 py-3 font-medium text-slate-900">
                  <.link navigate={~p"/fixtures/#{odds.fixture_id}"} class="text-emerald-700 hover:underline">
                    {fixture_name(odds.fixture)}
                  </.link>
                  <div class="text-xs font-normal text-slate-500">{format_datetime(odds.fixture.kickoff_at)}</div>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{odds.fixture.league.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{odds.market.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{odds.selection.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{odds.bookmaker.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{format_decimal(odds.decimal_odds)}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">{format_datetime(odds.captured_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp dashboard_data do
    start_at = DateTime.utc_now() |> DateTime.add(-60 * 60, :second) |> DateTime.truncate(:second)
    end_at = DateTime.add(start_at, 14 * 24 * 60 * 60, :second)

    {recommendations, recommendations_error} = load_recommendations(start_at, end_at)

    {latest_odds, latest_odds_error} =
      if Enum.empty?(recommendations) do
        load_latest_captured_odds()
      else
        {[], nil}
      end

    dashboard_error = dashboard_error(recommendations_error, latest_odds_error, latest_odds)

    {recommendations, latest_odds, dashboard_error}
  end

  defp load_recommendations(start_at, end_at) do
    recommendations =
      from(r in ValueRecommendation,
        join: f in assoc(r, :fixture),
        where: f.kickoff_at >= ^start_at and f.kickoff_at <= ^end_at,
        where: r.status in ["new", "notified", "accepted", "open"],
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
      Logger.warning("Unable to load dashboard recommendations: #{Exception.message(error)}")
      {[], error}
  end

  defp load_latest_captured_odds() do
    {latest_captured_odds(), nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Unable to load dashboard odds snapshots: #{Exception.message(error)}")
      {[], error}
  end

  defp dashboard_error(nil, nil, _latest_odds), do: nil
  defp dashboard_error(_recommendations_error, nil, latest_odds) when latest_odds != [], do: nil

  defp dashboard_error(_recommendations_error, _latest_odds_error, _latest_odds),
    do: "Please make sure the database is reachable and migrations have been run."

  defp latest_captured_odds do
    latest_ids =
      from(o in OddsSnapshot,
        distinct: [o.fixture_id, o.bookmaker_id, o.market_id, o.selection_id],
        order_by: [
          asc: o.fixture_id,
          asc: o.bookmaker_id,
          asc: o.market_id,
          asc: o.selection_id,
          desc: o.captured_at,
          desc: o.id
        ],
        select: o.id,
        limit: 100
      )

    from(o in OddsSnapshot,
      where: o.id in subquery(latest_ids),
      order_by: [desc: o.captured_at, desc: o.id],
      preload: [
        fixture: [:league, :home_team, :away_team],
        market: [],
        selection: [],
        bookmaker: []
      ]
    )
    |> Repo.all()
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

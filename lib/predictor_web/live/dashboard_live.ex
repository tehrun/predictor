defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view

  import Ecto.Query

  alias Predictor.Catalog.Fixture
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Repo
  alias Predictor.Scanner.Config, as: ScannerConfig
  alias Predictor.Value.{FairOdd, ValueRecommendation}

  require Logger

  @default_league_slug "world-cup-2026"
  @lookahead_days 180

  @impl true
  def mount(_params, _session, socket) do
    league_slug = world_cup_league_slug()

    {fixtures, recommendations_by_fixture, data_status, dashboard_error} =
      dashboard_data(league_slug)

    {:ok,
     socket
     |> assign(:page_title, "World Cup 2026 predictions")
     |> assign(:league_slug, league_slug)
     |> assign(:fixtures, fixtures)
     |> assign(:recommendations_by_fixture, recommendations_by_fixture)
     |> assign(:data_status, data_status)
     |> assign(:dashboard_error, dashboard_error)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-7xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">World Cup 2026</p>
        <h1 class="text-3xl font-bold text-slate-900">Upcoming World Cup 2026 predictions</h1>
        <p class="text-slate-600">
          Fixtures and positive expected-value recommendations filtered to the <span class="font-semibold">{@league_slug}</span> league.
        </p>
        <div class="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-900">
          <p>
            <span class="font-semibold">Informational only — no guaranteed profit.</span>
            Cap recommendations by configured bankroll and limits. Do not automate bet placement until positive
            closing-line value is proven and provider terms plus legal requirements are reviewed.
          </p>
        </div>
      </header>

      <div
        :if={@dashboard_error}
        class="rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-900"
      >
        <p class="font-semibold">World Cup 2026 data is temporarily unavailable.</p>
        <p>{@dashboard_error}</p>
      </div>

      <div :if={!@dashboard_error and Enum.empty?(@fixtures)} class="rounded-xl border border-dashed border-slate-200 bg-white px-5 py-5 text-sm text-slate-600 shadow-sm">
        <p class="font-semibold text-slate-900">No World Cup 2026 fixtures are loaded.</p>
        <p>No upcoming fixtures were found for league slug <span class="font-semibold">{@league_slug}</span>. Import the tournament schedule or update the scanner league slug before odds, fair probabilities, or recommendations can appear.</p>
      </div>

      <div :if={!@dashboard_error and !Enum.empty?(@fixtures)} class="space-y-4">
        <div :if={@data_status != :ready} class="rounded-xl border border-slate-200 bg-white px-5 py-4 text-sm text-slate-600 shadow-sm">
          <p class="font-semibold text-slate-900">World Cup 2026 fixtures are loaded, but predictions are incomplete.</p>
          <p :if={@data_status == :missing_odds}>Odds snapshots are missing for these fixtures, so fair probabilities and value recommendations cannot be generated yet.</p>
          <p :if={@data_status == :missing_fair_probabilities}>Odds snapshots exist, but fair probabilities/fair odds have not been calculated yet; recommendations will appear after the fair-odds engine runs.</p>
          <p :if={@data_status == :missing_recommendations}>Fixtures, odds, and fair probabilities exist, but no selection currently clears the configured EV/confidence thresholds for a recommendation.</p>
        </div>

        <article :for={fixture <- @fixtures} class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
          <div class="grid gap-4 px-4 py-4 sm:px-5 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,2fr)] lg:items-center">
            <div class="min-w-0 space-y-1">
              <.link navigate={~p"/fixtures/#{fixture.id}"} class="block truncate font-semibold text-slate-900 hover:text-emerald-700 hover:underline">
                {fixture_name(fixture)}
              </.link>
              <div class="flex flex-wrap gap-x-3 gap-y-1 text-xs text-slate-500">
                <span>{fixture.league.name}</span>
                <span>{format_datetime(fixture.kickoff_at)}</span>
                <span>{String.capitalize(fixture.status || "scheduled")}</span>
              </div>
            </div>

            <div :if={rec = Map.get(@recommendations_by_fixture, fixture.id)} class="grid gap-3 text-sm sm:grid-cols-3 lg:grid-cols-6 lg:items-center">
              <div class="sm:col-span-3 lg:col-span-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Predicted winner / selection</p>
                <p class="truncate font-semibold text-slate-900">{rec.selection.name}</p>
                <p class="text-xs text-slate-500">{rec.market.name} · {rec.bookmaker.name}</p>
              </div>
              <.metric label="Confidence" value={format_rating(rec.confidence_score)} />
              <.metric label="Fair probability" value={format_probability(rec.fair_probability)} />
              <.metric label="Fair odds" value={format_decimal(rec.fair_odds)} />
              <div>
                <p class="text-xs text-slate-500">EV / stake</p>
                <p class="font-semibold text-slate-900">{format_percent(rec.ev_percentage)} · {format_decimal(rec.recommended_stake)}</p>
              </div>
            </div>

            <div :if={!Map.has_key?(@recommendations_by_fixture, fixture.id)} class="rounded-lg border border-dashed border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
              <p class="font-semibold text-slate-800">No value recommendation for this match yet.</p>
              <p>The fixture is listed so you can track it while odds, fair probabilities, and EV checks catch up.</p>
            </div>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :string, required: true)

  defp metric(assigns) do
    ~H"""
    <div>
      <p class="text-xs text-slate-500">{@label}</p>
      <p class="font-semibold text-slate-900">{@value}</p>
    </div>
    """
  end

  defp dashboard_data(league_slug) do
    start_at = DateTime.utc_now() |> DateTime.add(-60 * 60, :second) |> DateTime.truncate(:second)
    end_at = DateTime.add(start_at, @lookahead_days * 24 * 60 * 60, :second)

    {fixtures, fixtures_error} = load_fixtures(league_slug, start_at, end_at)
    fixture_ids = Enum.map(fixtures, & &1.id)
    {recommendations, recommendations_error} = load_recommendations(fixture_ids)
    {has_odds?, odds_error} = has_odds?(fixture_ids)
    {has_fair_odds?, fair_odds_error} = has_fair_odds?(fixture_ids)

    recommendations_by_fixture =
      recommendations
      |> Enum.group_by(& &1.fixture_id)
      |> Map.new(fn {fixture_id, recs} ->
        {fixture_id, Enum.max_by(recs, &recommendation_sort_key/1)}
      end)

    data_status = data_status(fixtures, recommendations, has_odds?, has_fair_odds?)
    error = dashboard_error([fixtures_error, recommendations_error, odds_error, fair_odds_error])

    {fixtures, recommendations_by_fixture, data_status, error}
  end

  defp load_fixtures(league_slug, start_at, end_at) do
    fixtures =
      from(f in Fixture,
        join: l in assoc(f, :league),
        where: l.slug == ^league_slug,
        where: f.kickoff_at >= ^start_at and f.kickoff_at <= ^end_at,
        where: f.status in ["scheduled", "pending", "postponed"],
        order_by: [asc: f.kickoff_at, asc: f.id],
        preload: [:league, :home_team, :away_team],
        limit: 100
      )
      |> Repo.all()

    {fixtures, nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      Logger.warning("Unable to load World Cup fixtures: #{Exception.message(error)}")
      {[], error}
  end

  defp load_recommendations([]), do: {[], nil}

  defp load_recommendations(fixture_ids) do
    recommendations =
      from(r in ValueRecommendation,
        where: r.fixture_id in ^fixture_ids,
        where: r.status in ["new", "notified", "accepted", "open"],
        order_by: [desc: r.ev_percentage, desc: r.confidence_score],
        preload: [
          fixture: [:league, :home_team, :away_team],
          market: [],
          selection: [],
          bookmaker: []
        ]
      )
      |> Repo.all()

    {recommendations, nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      Logger.warning("Unable to load World Cup recommendations: #{Exception.message(error)}")
      {[], error}
  end

  defp has_odds?([]), do: {false, nil}

  defp has_odds?(fixture_ids) do
    exists? = Repo.exists?(from(o in OddsSnapshot, where: o.fixture_id in ^fixture_ids))
    {exists?, nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      {false, error}
  end

  defp has_fair_odds?([]), do: {false, nil}

  defp has_fair_odds?(fixture_ids) do
    exists? = Repo.exists?(from(f in FairOdd, where: f.fixture_id in ^fixture_ids))
    {exists?, nil}
  rescue
    error in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      {false, error}
  end

  defp data_status([], _recommendations, _has_odds?, _has_fair_odds?), do: :missing_fixtures

  defp data_status(_fixtures, recommendations, _has_odds?, _has_fair_odds?)
       when recommendations != [],
       do: :ready

  defp data_status(_fixtures, _recommendations, false, _has_fair_odds?), do: :missing_odds
  defp data_status(_fixtures, _recommendations, true, false), do: :missing_fair_probabilities
  defp data_status(_fixtures, _recommendations, true, true), do: :missing_recommendations

  defp dashboard_error(errors) do
    if Enum.any?(errors, & &1),
      do: "Please make sure the database is reachable and migrations have been run.",
      else: nil
  end

  defp world_cup_league_slug do
    case ScannerConfig.load().enabled_leagues do
      [slug | _] -> slug
      [] -> Application.get_env(:predictor, :world_cup_2026_league_slug, @default_league_slug)
    end
  rescue
    _error -> @default_league_slug
  end

  defp recommendation_sort_key(rec),
    do: {decimal_float(rec.ev_percentage), decimal_float(rec.confidence_score)}

  defp decimal_float(nil), do: 0.0
  defp decimal_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)

  defp fixture_name(fixture), do: "#{fixture.home_team.name} vs #{fixture.away_team.name}"
  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y · %H:%M UTC")
  defp format_decimal(nil), do: "—"
  defp format_decimal(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  defp format_percent(nil), do: "—"
  defp format_percent(decimal), do: "#{format_decimal(decimal)}%"
  defp format_probability(nil), do: "—"
  defp format_probability(decimal), do: decimal |> Decimal.mult(100) |> format_percent()
  defp format_rating(nil), do: "—"

  defp format_rating(decimal),
    do: "#{decimal |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string(:normal)} / 100"
end

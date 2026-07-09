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
          Server-rendered LiveView list of positive expected-value opportunities for upcoming fixtures.
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
        <p class="font-semibold">Dashboard data is temporarily unavailable.</p>
        <p>{@dashboard_error}</p>
      </div>

      <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        <div :if={@dashboard_error} class="px-4 py-8 text-center text-sm text-amber-700">
          Value recommendations cannot be loaded until the database issue above is resolved.
        </div>
        <div
          :if={!@dashboard_error and Enum.empty?(@recommendations)}
          class="px-4 py-5"
        >
          <div class="rounded-lg border border-dashed border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
            <p class="font-semibold text-slate-800">No qualifying value bets yet.</p>
            <p :if={!Enum.empty?(@latest_odds)}>
              Odds ingestion has captured data, but no upcoming fixtures currently pass the value threshold. Latest captured odds are shown below.
            </p>
            <p :if={Enum.empty?(@latest_odds)}>
              Odds ingestion has not produced visible data yet. Check back after snapshots are captured and recommendations are generated.
            </p>
          </div>
        </div>

        <div
          :if={!@dashboard_error and !Enum.empty?(@recommendations)}
          class="divide-y divide-slate-100"
        >
          <article
            :for={rec <- @recommendations}
            class="grid gap-4 px-4 py-4 transition hover:bg-slate-50 sm:px-5 lg:grid-cols-[minmax(0,1.6fr)_minmax(0,1.1fr)_minmax(0,1.2fr)_auto] lg:items-center"
          >
            <div class="min-w-0 space-y-1">
              <.link
                navigate={~p"/fixtures/#{rec.fixture_id}"}
                class="block truncate font-semibold text-slate-900 hover:text-emerald-700 hover:underline"
              >
                {fixture_name(rec.fixture)}
              </.link>
              <div class="flex flex-wrap gap-x-3 gap-y-1 text-xs text-slate-500">
                <span>{rec.fixture.league.name}</span>
                <span>{format_datetime(rec.fixture.kickoff_at)}</span>
              </div>
            </div>

            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">{rec.market.name}</p>
              <p class="truncate text-sm font-semibold text-slate-900">{rec.selection.name}</p>
            </div>

            <div class="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4 lg:grid-cols-[auto_auto_auto_auto] lg:items-center lg:justify-end">
              <div class="col-span-2 sm:col-span-1 lg:col-span-1">
                <.bookmaker_badge name={rec.bookmaker.name} />
              </div>
              <div>
                <p class="text-xs text-slate-500">Odds</p>
                <p class="font-bold text-slate-900">{format_decimal(rec.odds)}</p>
              </div>
              <div>
                <p class="text-xs text-slate-500">EV</p>
                <.ev_badge value={rec.ev_percentage} />
              </div>
              <div>
                <p class="text-xs text-slate-500">Stake</p>
                <p class="font-semibold text-slate-900">{format_decimal(rec.recommended_stake)}</p>
              </div>
            </div>

            <div class="flex items-center justify-between gap-3 border-t border-slate-100 pt-3 text-xs text-slate-500 lg:block lg:border-t-0 lg:pt-0 lg:text-right">
              <div class="flex flex-wrap items-center gap-2 lg:mb-2 lg:justify-end">
                <span>Fair {format_decimal(rec.fair_odds)}</span>
                <.confidence_badge value={rec.confidence_score} />
              </div>
              <.link
                navigate={~p"/fixtures/#{rec.fixture_id}"}
                class="inline-flex items-center rounded-lg border border-emerald-200 px-3 py-1.5 text-xs font-semibold text-emerald-700 transition hover:border-emerald-300 hover:bg-emerald-50"
              >
                View fixture
              </.link>
            </div>
          </article>
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
                <th class="px-4 py-3">Bookmaker</th>
                <th class="px-4 py-3 text-right">Home</th>
                <th class="px-4 py-3 text-right">Draw</th>
                <th class="px-4 py-3 text-right">Away</th>
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
                <td class="whitespace-nowrap px-4 py-3 text-slate-700">{odds.bookmaker.name}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{selection_odds(odds, "Home")}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{selection_odds(odds, "Draw")}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{selection_odds(odds, "Away")}</td>
                <td class="whitespace-nowrap px-4 py-3 text-right">
                  <span
                    class={[
                      "inline-flex rounded-full px-2 py-1 text-xs font-medium",
                      stale_snapshot?(odds.captured_at) && "bg-amber-50 text-amber-700",
                      !stale_snapshot?(odds.captured_at) && "text-slate-600"
                    ]}
                    title={format_datetime(odds.captured_at)}
                  >
                    {format_relative_time(odds.captured_at)}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  attr(:value, :any, required: true)

  defp ev_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-bold text-emerald-700 ring-1 ring-inset ring-emerald-200">
      {format_percent(@value)}
    </span>
    """
  end

  attr(:value, :any, required: true)

  defp confidence_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
      Confidence {format_rating(@value)}
    </span>
    """
  end

  attr(:name, :string, required: true)

  defp bookmaker_badge(assigns) do
    ~H"""
    <span class="inline-flex max-w-full items-center rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 ring-1 ring-inset ring-slate-200">
      <span class="truncate">{@name}</span>
    </span>
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
    |> Enum.group_by(&{&1.fixture_id, &1.bookmaker_id, &1.market_id})
    |> Enum.map(fn {_fixture_bookmaker_market, snapshots} ->
      latest_snapshot = Enum.max_by(snapshots, &snapshot_sort_key/1)

      %{
        fixture_id: latest_snapshot.fixture_id,
        fixture: latest_snapshot.fixture,
        market: latest_snapshot.market,
        bookmaker: latest_snapshot.bookmaker,
        captured_at: latest_snapshot.captured_at,
        selections: Map.new(snapshots, &{&1.selection.name, &1})
      }
    end)
    |> Enum.sort_by(&snapshot_group_sort_key/1, :desc)
  end

  defp snapshot_sort_key(%{captured_at: %DateTime{} = captured_at, id: id}),
    do: {DateTime.to_unix(captured_at, :microsecond), id}

  defp snapshot_group_sort_key(%{captured_at: %DateTime{} = captured_at, fixture_id: fixture_id}),
    do: {DateTime.to_unix(captured_at, :microsecond), fixture_id}

  defp selection_odds(%{selections: selections}, selection_name) do
    selections
    |> Map.get(selection_name)
    |> case do
      nil -> "—"
      snapshot -> format_decimal(snapshot.decimal_odds)
    end
  end

  defp fixture_name(fixture), do: "#{fixture.home_team.name} vs #{fixture.away_team.name}"
  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %H:%M UTC")

  defp format_relative_time(nil), do: "Updated —"

  defp format_relative_time(%DateTime{} = dt) do
    seconds_ago = max(DateTime.diff(DateTime.utc_now(), dt, :second), 0)

    cond do
      seconds_ago < 60 ->
        "Updated just now"

      seconds_ago < 60 * 60 ->
        "Updated #{div(seconds_ago, 60)} #{pluralize(div(seconds_ago, 60), "minute")} ago"

      seconds_ago < 24 * 60 * 60 ->
        "Updated #{div(seconds_ago, 60 * 60)} #{pluralize(div(seconds_ago, 60 * 60), "hour")} ago"

      true ->
        "Updated #{div(seconds_ago, 24 * 60 * 60)} #{pluralize(div(seconds_ago, 24 * 60 * 60), "day")} ago"
    end
  end

  defp stale_snapshot?(nil), do: false

  defp stale_snapshot?(%DateTime{} = dt),
    do: DateTime.diff(DateTime.utc_now(), dt, :hour) >= 6

  defp pluralize(1, unit), do: unit
  defp pluralize(_count, unit), do: unit <> "s"

  defp format_decimal(nil), do: "—"
  defp format_decimal(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  defp format_percent(nil), do: "—"
  defp format_percent(decimal), do: "#{format_decimal(decimal)}%"
  defp format_rating(nil), do: "—"

  defp format_rating(decimal),
    do: "#{decimal |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string(:normal)} / 100"
end

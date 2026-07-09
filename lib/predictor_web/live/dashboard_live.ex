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
        <div class="rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-900">
          <p class="font-semibold">Informational only — no guaranteed profit.</p>
          <p>
            Recommendations must be capped by an explicitly configured bankroll, daily/weekly/monthly limits,
            and a per-bet maximum. Do not enable automated bet placement until positive closing-line value is proven
            and provider terms plus jurisdiction-specific legal requirements have been reviewed.
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
          class="px-4 py-8 text-center text-sm text-slate-500"
        >
          No qualifying value bets found for upcoming fixtures yet. Run odds ingestion and the dashboard will populate once recommendations are generated.
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
        :if={!@dashboard_error and !Enum.empty?(@latest_odds)}
        class="space-y-4 rounded-xl border border-slate-200 bg-white p-4 shadow-sm"
      >
        <div class="border-b border-slate-200 pb-3">
          <h2 class="font-semibold text-slate-900">Latest captured odds</h2>
          <p class="text-sm text-slate-600">
            Odds ingestion is reaching the database. Compare the newest captured bookmaker prices by fixture and market while value recommendations are generated.
          </p>
        </div>

        <div :for={fixture_group <- fixture_odds_groups(@latest_odds)} class="space-y-4 rounded-lg border border-slate-200 p-4">
          <div class="flex flex-col gap-2 md:flex-row md:items-start md:justify-between">
            <div>
              <.link navigate={~p"/fixtures/#{fixture_group.fixture.id}"} class="font-semibold text-emerald-700 hover:underline">
                {fixture_name(fixture_group.fixture)}
              </.link>
              <div class="text-sm text-slate-600">{fixture_group.fixture.league.name}</div>
              <div class="text-xs text-slate-500">Kickoff: {format_datetime(fixture_group.fixture.kickoff_at)}</div>
            </div>
            <div class="rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-700">
              {fixture_group.bookmaker_price_count} bookmaker prices
            </div>
          </div>

          <div :for={market_group <- fixture_group.markets} class="space-y-2">
            <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-600">{market_group.market.name}</h3>

            <div :if={one_x_two_market?(market_group)} class="overflow-x-auto rounded-lg border border-slate-200">
              <table class="min-w-full divide-y divide-slate-200 text-sm">
                <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
                  <tr>
                    <th class="px-3 py-2">Bookmaker</th>
                    <th class="px-3 py-2 text-right">Home</th>
                    <th class="px-3 py-2 text-right">Draw</th>
                    <th class="px-3 py-2 text-right">Away</th>
                    <th class="px-3 py-2 text-right">Updated</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <tr :for={bookmaker_group <- market_group.bookmakers} class="hover:bg-slate-50">
                    <td class="whitespace-nowrap px-3 py-2 font-medium text-slate-900">{bookmaker_group.bookmaker.name}</td>
                    <td :for={selection <- [:home, :draw, :away]} class={odds_cell_class(best_selection_odds?(market_group, selection, bookmaker_group.prices_by_outcome[selection]))}>
                      {format_decimal(price_odds(bookmaker_group.prices_by_outcome[selection]))}
                    </td>
                    <td class="whitespace-nowrap px-3 py-2 text-right text-slate-600">{format_datetime(bookmaker_group.updated_at)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div :if={!one_x_two_market?(market_group)} class="overflow-x-auto rounded-lg border border-slate-200">
              <table class="min-w-full divide-y divide-slate-200 text-sm">
                <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
                  <tr>
                    <th class="px-3 py-2">Bookmaker</th>
                    <th :for={selection <- market_group.selections} class="px-3 py-2 text-right">{selection.name}</th>
                    <th class="px-3 py-2 text-right">Updated</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <tr :for={bookmaker_group <- market_group.bookmakers} class="hover:bg-slate-50">
                    <td class="whitespace-nowrap px-3 py-2 font-medium text-slate-900">{bookmaker_group.bookmaker.name}</td>
                    <td :for={selection <- market_group.selections} class={odds_cell_class(best_selection_odds?(market_group, selection.id, bookmaker_group.prices_by_selection[selection.id]))}>
                      {format_decimal(price_odds(bookmaker_group.prices_by_selection[selection.id]))}
                    </td>
                    <td class="whitespace-nowrap px-3 py-2 text-right text-slate-600">{format_datetime(bookmaker_group.updated_at)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
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
  end

  defp fixture_odds_groups(latest_odds) do
    latest_odds
    |> Enum.group_by(& &1.fixture_id)
    |> Enum.map(fn {_fixture_id, fixture_odds} ->
      fixture = fixture_odds |> List.first() |> Map.fetch!(:fixture)

      %{
        fixture: fixture,
        bookmaker_price_count: length(fixture_odds),
        markets: market_odds_groups(fixture_odds)
      }
    end)
    |> Enum.sort_by(& &1.fixture.kickoff_at, {:asc, DateTime})
  end

  defp market_odds_groups(fixture_odds) do
    fixture_odds
    |> Enum.group_by(& &1.market_id)
    |> Enum.map(fn {_market_id, market_odds} ->
      market = market_odds |> List.first() |> Map.fetch!(:market)
      selections = market_odds |> Enum.map(& &1.selection) |> unique_by_id()

      %{
        market: market,
        selections: selections,
        best_by_selection: best_by_selection(market_odds),
        best_by_outcome: best_by_outcome(market_odds),
        bookmakers: bookmaker_odds_groups(market_odds)
      }
    end)
    |> Enum.sort_by(& &1.market.name)
  end

  defp bookmaker_odds_groups(market_odds) do
    market_odds
    |> Enum.group_by(& &1.bookmaker_id)
    |> Enum.map(fn {_bookmaker_id, bookmaker_odds} ->
      bookmaker = bookmaker_odds |> List.first() |> Map.fetch!(:bookmaker)

      %{
        bookmaker: bookmaker,
        prices_by_selection: Map.new(bookmaker_odds, &{&1.selection_id, &1}),
        prices_by_outcome: prices_by_outcome(bookmaker_odds),
        updated_at: latest_captured_at(bookmaker_odds)
      }
    end)
    |> Enum.sort_by(& &1.bookmaker.name)
  end

  defp unique_by_id(items) do
    items
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  defp prices_by_outcome(bookmaker_odds) do
    bookmaker_odds
    |> Enum.reduce(%{}, fn odds, acc ->
      case selection_outcome(odds.selection.name) do
        nil -> acc
        outcome -> Map.put(acc, outcome, odds)
      end
    end)
  end

  defp best_by_selection(market_odds) do
    market_odds
    |> Enum.group_by(& &1.selection_id)
    |> Map.new(fn {selection_id, odds} -> {selection_id, best_decimal_odds(odds)} end)
  end

  defp best_by_outcome(market_odds) do
    market_odds
    |> Enum.group_by(&selection_outcome(&1.selection.name))
    |> Map.drop([nil])
    |> Map.new(fn {outcome, odds} -> {outcome, best_decimal_odds(odds)} end)
  end

  defp best_decimal_odds(odds) do
    odds
    |> Enum.map(& &1.decimal_odds)
    |> Enum.reduce(fn odds, best ->
      if Decimal.compare(odds, best) == :gt, do: odds, else: best
    end)
  end

  defp latest_captured_at(odds) do
    odds
    |> Enum.map(& &1.captured_at)
    |> Enum.reduce(fn captured_at, latest ->
      if DateTime.compare(captured_at, latest) == :gt, do: captured_at, else: latest
    end)
  end

  defp one_x_two_market?(market_group) do
    [:home, :draw, :away]
    |> Enum.all?(&Map.has_key?(market_group.best_by_outcome, &1))
  end

  defp selection_outcome(name) do
    normalized = name |> to_string() |> String.downcase() |> String.trim()

    cond do
      normalized in ["home", "1"] or String.contains?(normalized, "home") -> :home
      normalized in ["draw", "x", "tie"] or String.contains?(normalized, "draw") -> :draw
      normalized in ["away", "2"] or String.contains?(normalized, "away") -> :away
      true -> nil
    end
  end

  defp best_selection_odds?(_market_group, _selection_key, nil), do: false

  defp best_selection_odds?(market_group, selection_key, odds) do
    best_odds =
      Map.get(market_group.best_by_selection, selection_key) ||
        Map.get(market_group.best_by_outcome, selection_key)

    not is_nil(best_odds) and Decimal.equal?(odds.decimal_odds, best_odds)
  end

  defp odds_cell_class(true),
    do: "whitespace-nowrap bg-emerald-50 px-3 py-2 text-right font-semibold text-emerald-700"

  defp odds_cell_class(false),
    do: "whitespace-nowrap px-3 py-2 text-right font-medium text-slate-900"

  defp price_odds(nil), do: nil
  defp price_odds(odds), do: odds.decimal_odds

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

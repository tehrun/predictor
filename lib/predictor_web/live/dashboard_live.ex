defmodule PredictorWeb.DashboardLive do
  use PredictorWeb, :live_view
  import Ecto.Query
  alias Predictor.Repo
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Value.ValueRecommendation
  require Logger

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, :page_title, "Value Betting Dashboard")}

  @impl true
  def handle_params(params, _uri, socket) do
    {recs, latest, error} = dashboard_data(params)

    groups =
      recs
      |> Enum.group_by(& &1.fixture)
      |> Enum.map(fn {f, rs} ->
        {f, Enum.sort_by(rs, &Decimal.to_float(&1.ev_percentage || Decimal.new(0)), :desc)}
      end)

    {:noreply,
     assign(socket,
       recommendations: recs,
       fixture_groups: groups,
       last_odds_update: latest,
       dashboard_error: error,
       filters: params,
       summary: summary(recs, latest)
     )}
  end

  @impl true
  def handle_event("filter", %{"filters" => f}, socket),
    do: {:noreply, push_patch(socket, to: ~p"/dashboard?#{clean(f)}")}

  def handle_event("clear_filters", _, socket),
    do: {:noreply, push_patch(socket, to: ~p"/dashboard")}

  def handle_event("track_bet", _, socket),
    do:
      {:noreply,
       put_flash(socket, :info, "Tracking workflow is ready for backend placement status.")}

  def handle_event("dismiss", _, socket),
    do: {:noreply, put_flash(socket, :info, "Opportunity dismissed for this session.")}

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <.page_header title="Value Betting Dashboard" eyebrow="Overview" description="Best positive-EV opportunities grouped by fixture, with stake, confidence, bookmaker, and freshness visible at a glance.">
        <:actions><.link navigate={~p"/opportunities"} class="rounded-xl bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700">View all opportunities</.link></:actions>
      </.page_header>

      <div class="rounded-2xl border border-blue-200 bg-blue-50 p-4 text-sm text-blue-900"><b>About value betting:</b> Recommendations are informational and depend on your bankroll and limits. Bet responsibly; no edge guarantees profit.</div>
      <div :if={@dashboard_error} class="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"><b>Data temporarily unavailable.</b> <%= @dashboard_error %></div>

      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-6">
        <.stat_card label="Opportunities" value={to_string(@summary.count)} hint="Qualifying now" tone="emerald" />
        <.stat_card label="Highest EV" value={ev(@summary.highest_ev)} hint="Best fixture edge" tone="emerald" />
        <.stat_card label="Recommended stake" value={currency(@summary.total_stake)} hint="Total suggested" />
        <.stat_card label="Open exposure" value={currency(@summary.total_stake)} hint="If all tracked" tone="amber" />
        <.stat_card label="Odds updated" value={short_datetime(@summary.last_update)} hint={relative(@summary.last_update)} />
        <.stat_card label="Scanner" value={String.capitalize(scanner_state(@summary.last_update))} hint="Freshness indicator" tone="emerald" />
      </div>

      <.form for={%{}} as={:filters} phx-change="filter" class="sticky top-0 z-10 rounded-2xl border border-slate-200 bg-white/95 p-4 shadow-sm backdrop-blur">
        <div class="grid gap-3 md:grid-cols-4 xl:grid-cols-8">
          <select name="filters[date]" class="rounded-xl border-slate-300 text-sm"><option value="">Any date</option><option value="today" selected={@filters["date"] == "today"}>Today</option><option value="tomorrow" selected={@filters["date"] == "tomorrow"}>Tomorrow</option><option value="7d" selected={@filters["date"] == "7d"}>Next 7 days</option></select>
          <input name="filters[sport]" value={@filters["sport"]} placeholder="Sport" class="rounded-xl border-slate-300 text-sm" />
          <input name="filters[league]" value={@filters["league"]} placeholder="League" class="rounded-xl border-slate-300 text-sm" />
          <input name="filters[market]" value={@filters["market"]} placeholder="Market" class="rounded-xl border-slate-300 text-sm" />
          <input name="filters[bookmaker]" value={@filters["bookmaker"]} placeholder="Bookmaker" class="rounded-xl border-slate-300 text-sm" />
          <input name="filters[min_ev]" value={@filters["min_ev"]} placeholder="Min EV %" type="number" class="rounded-xl border-slate-300 text-sm" />
          <input name="filters[min_odds]" value={@filters["min_odds"]} placeholder="Min odds" type="number" step="0.01" class="rounded-xl border-slate-300 text-sm" />
          <select name="filters[sort]" class="rounded-xl border-slate-300 text-sm"><option value="ev">Sort by EV</option><option value="kickoff" selected={@filters["sort"] == "kickoff"}>Kickoff</option></select>
        </div>
        <div class="mt-3 flex items-center justify-between text-sm"><span class="text-slate-600"><%= @summary.count %> results</span><button type="button" phx-click="clear_filters" class="font-semibold text-slate-700">Clear all</button></div>
      </.form>

      <div class="space-y-5">
        <.empty_state :if={!@dashboard_error and Enum.empty?(@fixture_groups)} title="No matching value bets" message="No opportunities currently match your filters. Odds may be captured without positive EV, or the scanner may not have completed its first run." action="Open scanner settings" href={~p"/settings/scanner"}/>
        <.fixture_card :for={{fixture, recs} <- @fixture_groups} fixture={fixture} recommendations={recs}/>
      </div>
    </section>
    """
  end

  defp dashboard_data(params) do
    start_at = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)
    end_at = DateTime.add(start_at, if(params["date"] == "7d", do: 7, else: 14) * 86400, :second)

    recs =
      from(r in ValueRecommendation,
        join: f in assoc(r, :fixture),
        where:
          f.kickoff_at >= ^start_at and f.kickoff_at <= ^end_at and
            r.status in ["new", "notified", "accepted", "open"],
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
      |> filter_memory(params)

    latest = Repo.one(from(o in OddsSnapshot, select: max(o.captured_at)))
    {recs, latest, nil}
  rescue
    e in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error, Ecto.NoResultsError] ->
      Logger.error("Dashboard load failed: #{Exception.message(e)}")
      {[], nil, "We could not load betting data. Please retry or check the scanner status."}
  end

  defp filter_memory(recs, p),
    do:
      Enum.filter(recs, fn r ->
        match_text?(r.fixture.league.name, p["league"]) and
          match_text?(r.market.name, p["market"]) and
          match_text?(r.bookmaker.name, p["bookmaker"]) and
          min_decimal?(r.ev_percentage, p["min_ev"]) and min_decimal?(r.odds, p["min_odds"])
      end)

  defp match_text?(_, v) when v in [nil, ""], do: true
  defp match_text?(text, v), do: String.contains?(String.downcase(text || ""), String.downcase(v))
  defp min_decimal?(_, v) when v in [nil, ""], do: true
  defp min_decimal?(d, v), do: Decimal.compare(d || Decimal.new(0), Decimal.new(v)) != :lt
  defp clean(map), do: Map.reject(map, fn {_, v} -> v in [nil, ""] end)

  defp summary(recs, latest),
    do: %{
      count: length(recs),
      highest_ev:
        Enum.map(recs, & &1.ev_percentage)
        |> Enum.reject(&is_nil/1)
        |> Enum.max_by(&Decimal.to_float/1, fn -> nil end),
      total_stake:
        Enum.reduce(
          recs,
          Decimal.new(0),
          &Decimal.add(&2, &1.recommended_stake || Decimal.new(0))
        ),
      last_update: latest
    }
end

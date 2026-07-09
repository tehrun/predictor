defmodule PredictorWeb.FixtureLive do
  use PredictorWeb, :live_view
  import Ecto.Query
  alias Predictor.Catalog.Fixture
  alias Predictor.Odds.{ClosingLine, OddsSnapshot}
  alias Predictor.Repo
  alias Predictor.Value.{FairOdd, ValueRecommendation}
  require Logger

  def mount(%{"id" => id}, _session, socket) do
    {data, error} = load_all(id)
    title = if data.fixture, do: fixture_name(data.fixture), else: "Fixture"

    {:ok,
     assign(
       socket,
       Map.merge(data, %{
         page_title: title,
         fixture_error: error,
         active_tab: "overview",
         last_odds_update: latest(data.odds_history)
       })
     )}
  end

  def handle_event("tab", %{"tab" => tab}, socket),
    do: {:noreply, assign(socket, :active_tab, tab)}

  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <.link navigate={~p"/dashboard"} class="text-sm font-semibold text-emerald-700">← Back to dashboard</.link>
      <.empty_state :if={@fixture_error && is_nil(@fixture)} title="Fixture unavailable" message="We could not load this fixture. The error was logged so the page does not crash." action="Back to dashboard" href={~p"/dashboard"}/>
      <div :if={@fixture} class="space-y-8">
        <.page_header title={fixture_name(@fixture)} eyebrow={@fixture.league.name} description={"#{datetime(@fixture.kickoff_at)} · #{relative(@fixture.kickoff_at)} · #{@fixture.status}"}/>
        <div :if={@fixture_error} class="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"><b>Partial data unavailable.</b> Some fixture associations or market data could not be loaded.</div>
        <div class="grid gap-4 xl:grid-cols-4"><.stat_card label="Value opportunities" value={to_string(length(@recommendations))} tone="emerald"/><.stat_card label="Best EV" value={ev(best(@recommendations, :ev_percentage))} tone="emerald"/><.stat_card label="Best price" value={odds(best(@odds_history, :decimal_odds))}/><.stat_card label="Odds freshness" value={short_datetime(latest(@odds_history))} hint={relative(latest(@odds_history))}/></div>
        <section class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm"><h2 class="text-xl font-bold">Best recommendation</h2><div class="mt-4"><.empty_state :if={Enum.empty?(@recommendations)} title="No recommendation for this fixture" message="Fair odds may not be available or no market currently clears the EV threshold."/><.recommendation_card :if={!Enum.empty?(@recommendations)} rec={hd(@recommendations)}/></div></section>
        <div role="tablist" aria-label="Fixture sections" class="flex gap-2 overflow-x-auto rounded-2xl bg-white p-2 shadow-sm"><button :for={tab <- ["overview","odds","movement","recommendations","closing","raw"]} role="tab" aria-selected={@active_tab == tab} phx-click="tab" phx-value-tab={tab} class={["rounded-xl px-4 py-2 text-sm font-semibold", @active_tab == tab && "bg-slate-900 text-white", @active_tab != tab && "text-slate-600 hover:bg-slate-100"]}><%= String.capitalize(tab) %></button></div>
        <.panel :if={@active_tab in ["overview","odds","raw"]} title="Odds comparison"><.odds_matrix rows={@odds_history}/></.panel>
        <.panel :if={@active_tab == "movement"} title="Odds movement"><.timeline rows={Enum.take(@odds_history, 40)} time_field={:captured_at} /></.panel>
        <.panel :if={@active_tab == "recommendations"} title="Recommendation history"><.timeline rows={@recommendations} time_field={:recommended_at} /></.panel>
        <.panel :if={@active_tab == "closing"} title="Closing line"><.timeline rows={@closing_lines} time_field={:captured_at} /></.panel>
      </div>
    </section>
    """
  end

  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  defp panel(assigns) do
    ~H"""
    <section class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm"><h2 class="mb-4 text-xl font-bold"><%= @title %></h2><%= render_slot(@inner_block) %></section>
    """
  end

  attr(:rows, :list, required: true)

  defp odds_matrix(assigns) do
    ~H"""
    <.empty_state :if={Enum.empty?(@rows)} title="No odds captured" message="The scanner has not stored odds snapshots for this fixture yet."/><div class="grid gap-2"><div :for={r <- Enum.take(@rows, 60)} class="grid grid-cols-2 gap-2 rounded-xl bg-slate-50 p-3 text-sm md:grid-cols-5"><b><%= r.bookmaker.name %></b><span><%= r.market.name %></span><span><%= r.selection.name %></span><span class="font-semibold tabular-nums"><%= odds(r.decimal_odds) %></span><span class="text-slate-500"><%= short_datetime(r.captured_at) %></span></div></div>
    """
  end

  attr(:rows, :list, required: true)
  attr(:time_field, :atom, required: true)

  defp timeline(assigns) do
    ~H"""
    <.empty_state :if={Enum.empty?(@rows)} title="No records yet" message="This timeline will fill in as the scanner and recommendation engine collect data."/><ol class="space-y-3"><li :for={r <- @rows} class="rounded-xl bg-slate-50 p-3 text-sm"><time class="font-semibold"><%= short_datetime(Map.get(r, @time_field)) %></time><span class="ml-2 text-slate-600"><%= Map.get(r, :bookmaker) && Map.get(r,:bookmaker).name %> <%= Map.get(r, :market) && Map.get(r,:market).name %> <%= Map.get(r,:selection) && Map.get(r,:selection).name %></span><span class="float-right font-semibold tabular-nums"><%= odds(Map.get(r, :decimal_odds) || Map.get(r, :odds)) %></span></li></ol>
    """
  end

  defp load_all(id) do
    fixture = Repo.get(Fixture, id) |> Repo.preload([:league, :home_team, :away_team])

    if is_nil(fixture),
      do:
        {%{
           fixture: nil,
           odds_history: [],
           fair_probabilities: [],
           recommendations: [],
           closing_lines: []
         }, "Fixture not found"},
      else:
        {%{
           fixture: fixture,
           odds_history: q(OddsSnapshot, id, :captured_at, [:bookmaker, :market, :selection]),
           fair_probabilities: q(FairOdd, id, :calculated_at, [:market, :selection]),
           recommendations:
             q(ValueRecommendation, id, :recommended_at, [:bookmaker, :market, :selection]),
           closing_lines: q(ClosingLine, id, :captured_at, [:bookmaker, :market, :selection])
         }, nil}
  rescue
    e in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error, ArgumentError] ->
      Logger.error("Fixture load failed id=#{id}: #{Exception.message(e)}")

      {%{
         fixture: nil,
         odds_history: [],
         fair_probabilities: [],
         recommendations: [],
         closing_lines: []
       }, "Fixture data could not be loaded."}
  end

  defp q(schema, id, field, preloads),
    do:
      Repo.all(
        from(x in schema,
          where: x.fixture_id == ^id,
          order_by: [desc: field(x, ^field), desc: x.id],
          preload: ^preloads,
          limit: 100
        )
      )

  defp fixture_name(f), do: "#{f.home_team.name} vs #{f.away_team.name}"
  defp latest([]), do: nil

  defp latest(rows),
    do:
      rows
      |> Enum.map(&Map.get(&1, :captured_at))
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)

  defp best([], _), do: nil

  defp best(rows, field),
    do:
      rows
      |> Enum.map(&Map.get(&1, field))
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(&Decimal.to_float/1, fn -> nil end)
end

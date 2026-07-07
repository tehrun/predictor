defmodule PredictorWeb.FixtureLive do
  use PredictorWeb, :live_view

  import Ecto.Query

  alias Predictor.Catalog.Fixture
  alias Predictor.Odds.{ClosingLine, OddsSnapshot}
  alias Predictor.Repo
  alias Predictor.Value.{FairOdd, ValueRecommendation}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    fixture = load_fixture!(id)

    {:ok,
     socket
     |> assign(:page_title, fixture_name(fixture))
     |> assign(:fixture, fixture)
     |> assign(:odds_history, odds_history(id))
     |> assign(:fair_probabilities, fair_probabilities(id))
     |> assign(:recommendation_history, recommendation_history(id))
     |> assign(:closing_lines, closing_lines(id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-7xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <.link navigate={~p"/dashboard"} class="text-sm font-semibold text-emerald-700 hover:underline">← Dashboard</.link>
        <h1 class="text-3xl font-bold text-slate-900">{fixture_name(@fixture)}</h1>
        <p class="text-slate-600">{@fixture.league.name} · {format_datetime(@fixture.kickoff_at)} · {@fixture.status}</p>
      </header>

      <.panel title="Odds history by bookmaker">
        <.data_table rows={@odds_history} empty="No odds snapshots captured yet.">
          <:col :let={row} label="Captured">{format_datetime(row.captured_at)}</:col>
          <:col :let={row} label="Bookmaker">{row.bookmaker.name}</:col>
          <:col :let={row} label="Market">{row.market.name}</:col>
          <:col :let={row} label="Selection">{row.selection.name}</:col>
          <:col :let={row} label="Odds" align="right">{format_decimal(row.decimal_odds)}</:col>
        </.data_table>
      </.panel>

      <.panel title="Fair probabilities">
        <.data_table rows={@fair_probabilities} empty="No fair probabilities calculated yet.">
          <:col :let={row} label="Calculated">{format_datetime(row.calculated_at)}</:col>
          <:col :let={row} label="Market">{row.market.name}</:col>
          <:col :let={row} label="Selection">{row.selection.name}</:col>
          <:col :let={row} label="Engine">{row.source_engine}</:col>
          <:col :let={row} label="Probability" align="right">{format_probability(row.implied_probability)}</:col>
          <:col :let={row} label="Fair odds" align="right">{format_decimal(row.fair_odds)}</:col>
        </.data_table>
      </.panel>

      <.panel title="Recommendation history">
        <.data_table rows={@recommendation_history} empty="No recommendations generated for this fixture yet.">
          <:col :let={row} label="Recommended">{format_datetime(row.recommended_at)}</:col>
          <:col :let={row} label="Bookmaker">{row.bookmaker.name}</:col>
          <:col :let={row} label="Market">{row.market.name}</:col>
          <:col :let={row} label="Selection">{row.selection.name}</:col>
          <:col :let={row} label="EV %" align="right">{format_percent(row.ev_percentage)}</:col>
          <:col :let={row} label="Stake" align="right">{format_decimal(row.recommended_stake)}</:col>
          <:col :let={row} label="Status">{row.status}</:col>
        </.data_table>
      </.panel>

      <.panel title="Closing-line data after kickoff">
        <.data_table rows={@closing_lines} empty="No closing lines captured yet.">
          <:col :let={row} label="Captured">{format_datetime(row.captured_at)}</:col>
          <:col :let={row} label="Bookmaker">{row.bookmaker.name}</:col>
          <:col :let={row} label="Market">{row.market.name}</:col>
          <:col :let={row} label="Selection">{row.selection.name}</:col>
          <:col :let={row} label="Closing odds" align="right">{format_decimal(row.decimal_odds)}</:col>
        </.data_table>
      </.panel>
    </section>
    """
  end

  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  defp panel(assigns) do
    ~H"""
    <section class="rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 class="mb-4 text-xl font-semibold text-slate-900">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr(:rows, :list, required: true)
  attr(:empty, :string, required: true)

  slot :col, required: true do
    attr(:label, :string, required: true)
    attr(:align, :string)
  end

  defp data_table(assigns) do
    ~H"""
    <div class="overflow-x-auto"><table class="min-w-full divide-y divide-slate-200 text-sm"><thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600"><tr><th :for={col <- @col} class={["px-4 py-3", col[:align] == "right" && "text-right"]}>{col.label}</th></tr></thead><tbody class="divide-y divide-slate-100"><tr :if={Enum.empty?(@rows)}><td colspan={length(@col)} class="px-4 py-6 text-center text-slate-500">{@empty}</td></tr><tr :for={row <- @rows} class="hover:bg-slate-50"><td :for={col <- @col} class={["whitespace-nowrap px-4 py-3 text-slate-700", col[:align] == "right" && "text-right"]}>{render_slot(col, row)}</td></tr></tbody></table></div>
    """
  end

  defp load_fixture!(id),
    do: Repo.get!(Fixture, id) |> Repo.preload([:league, :home_team, :away_team])

  defp odds_history(id),
    do:
      Repo.all(
        from(o in OddsSnapshot,
          where: o.fixture_id == ^id,
          order_by: [asc: o.captured_at, asc: o.id],
          preload: [:bookmaker, :market, :selection]
        )
      )

  defp fair_probabilities(id),
    do:
      Repo.all(
        from(f in FairOdd,
          where: f.fixture_id == ^id,
          order_by: [desc: f.calculated_at, desc: f.id],
          preload: [:market, :selection]
        )
      )

  defp recommendation_history(id),
    do:
      Repo.all(
        from(r in ValueRecommendation,
          where: r.fixture_id == ^id,
          order_by: [desc: r.recommended_at, desc: r.id],
          preload: [:bookmaker, :market, :selection]
        )
      )

  defp closing_lines(id),
    do:
      Repo.all(
        from(c in ClosingLine,
          where: c.fixture_id == ^id,
          order_by: [desc: c.captured_at, desc: c.id],
          preload: [:bookmaker, :market, :selection]
        )
      )

  defp fixture_name(fixture), do: "#{fixture.home_team.name} vs #{fixture.away_team.name}"
  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y %H:%M UTC")
  defp format_decimal(nil), do: "—"
  defp format_decimal(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  defp format_percent(nil), do: "—"
  defp format_percent(decimal), do: "#{format_decimal(decimal)}%"
  defp format_probability(nil), do: "—"

  defp format_probability(decimal),
    do: "#{decimal |> Decimal.mult(100) |> Decimal.round(2) |> Decimal.to_string(:normal)}%"
end

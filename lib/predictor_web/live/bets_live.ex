defmodule PredictorWeb.BetsLive do
  use PredictorWeb, :live_view

  import Ecto.Query

  alias Predictor.Betting.Bet
  alias Predictor.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Tracked bets") |> assign(:bets, tracked_bets())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-7xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">Bets</p>
        <h1 class="text-3xl font-bold text-slate-900">Tracked accepted bets</h1>
        <p class="text-slate-600">Settled and in-flight accepted bets with result, profit/loss, and closing-line value.</p>
      </header>

      <div class="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm"><div class="overflow-x-auto"><table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600"><tr><th class="px-4 py-3">Placed</th><th class="px-4 py-3">Fixture</th><th class="px-4 py-3">Market</th><th class="px-4 py-3">Selection</th><th class="px-4 py-3">Bookmaker</th><th class="px-4 py-3 text-right">Stake</th><th class="px-4 py-3 text-right">Odds</th><th class="px-4 py-3">Result</th><th class="px-4 py-3 text-right">P/L</th><th class="px-4 py-3 text-right">CLV</th></tr></thead>
        <tbody class="divide-y divide-slate-100"><tr :if={Enum.empty?(@bets)}><td colspan="10" class="px-4 py-8 text-center text-slate-500">No accepted bets are being tracked yet.</td></tr><tr :for={bet <- @bets} class="hover:bg-slate-50"><td class="whitespace-nowrap px-4 py-3 text-slate-700">{format_datetime(bet.placed_at)}</td><td class="whitespace-nowrap px-4 py-3 font-medium text-slate-900"><.link navigate={~p"/fixtures/#{bet.fixture_id}"} class="text-emerald-700 hover:underline">{fixture_name(bet.fixture)}</.link></td><td class="whitespace-nowrap px-4 py-3 text-slate-700">{bet.market.name}</td><td class="whitespace-nowrap px-4 py-3 text-slate-700">{bet.selection.name}</td><td class="whitespace-nowrap px-4 py-3 text-slate-700">{bet.bookmaker.name}</td><td class="whitespace-nowrap px-4 py-3 text-right">{format_decimal(bet.stake)}</td><td class="whitespace-nowrap px-4 py-3 text-right">{format_decimal(bet.odds_taken)}</td><td class="whitespace-nowrap px-4 py-3 text-slate-700">{bet.result || bet.status}</td><td class={["whitespace-nowrap px-4 py-3 text-right font-semibold", profit_class(bet.profit_loss)]}>{format_decimal(bet.profit_loss)}</td><td class="whitespace-nowrap px-4 py-3 text-right">{format_percent(bet.clv_percentage)}</td></tr></tbody>
      </table></div></div>
    </section>
    """
  end

  defp tracked_bets do
    Repo.all(
      from(b in Bet,
        where: b.status in ["accepted", "placed", "settled"],
        order_by: [desc: b.placed_at, desc: b.id],
        preload: [fixture: [:home_team, :away_team], market: [], selection: [], bookmaker: []],
        limit: 200
      )
    )
  end

  defp fixture_name(fixture), do: "#{fixture.home_team.name} vs #{fixture.away_team.name}"
  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y %H:%M UTC")
  defp format_decimal(nil), do: "—"
  defp format_decimal(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  defp format_percent(nil), do: "—"
  defp format_percent(decimal), do: "#{format_decimal(decimal)}%"
  defp profit_class(nil), do: "text-slate-700"

  defp profit_class(decimal),
    do: if(Decimal.compare(decimal, 0) == :lt, do: "text-rose-700", else: "text-emerald-700")
end

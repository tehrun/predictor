defmodule PredictorWeb.BetsLive do
  use PredictorWeb, :live_view
  import Ecto.Query
  alias Predictor.Betting.Bet
  alias Predictor.Repo
  require Logger

  def mount(_params, _session, socket) do
    {bets, error} = load_bets()

    {:ok,
     assign(socket,
       page_title: "My Bets",
       bets: bets,
       bets_error: error,
       page: 1,
       last_odds_update: nil,
       summary: perf(bets)
     )}
  end

  def render(assigns) do
    ~H"""
    <section class="space-y-8"><.page_header title="My Bets" eyebrow="Performance" description="Track placed, pending, settled, won, lost, and void bets as coherent decisions rather than raw rows."/>
    <div :if={@bets_error} class="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"><b>Bets unavailable.</b> We logged the data issue and kept the page available.</div>
    <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-6"><.stat_card label="Profit/Loss" value={profit(@summary.pl)} tone={if Decimal.compare(@summary.pl, 0) == :lt, do: "rose", else: "emerald"}/><.stat_card label="ROI" value={@summary.roi}/><.stat_card label="Win rate" value={@summary.win_rate}/><.stat_card label="Total staked" value={currency(@summary.staked)}/><.stat_card label="Open exposure" value={currency(@summary.open)}/><.stat_card label="Settled" value={@summary.settled}/></div>
    <div class="rounded-2xl border border-slate-200 bg-white p-4"><div class="grid gap-3 md:grid-cols-7"><input placeholder="Search team or fixture" class="rounded-xl border-slate-300 text-sm md:col-span-2"/><select class="rounded-xl border-slate-300 text-sm"><option>Status</option></select><select class="rounded-xl border-slate-300 text-sm"><option>Result</option></select><input placeholder="League" class="rounded-xl border-slate-300 text-sm"/><input placeholder="Bookmaker" class="rounded-xl border-slate-300 text-sm"/><input placeholder="Min stake" class="rounded-xl border-slate-300 text-sm"/></div></div>
    <.empty_state :if={Enum.empty?(@bets) and !@bets_error} title="No bets tracked yet" message="Accepted or placed recommendations will appear here with stake, potential return, result, P/L and CLV." action="Find opportunities" href={~p"/dashboard"}/>
    <div class="hidden overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm md:block"><table class="min-w-full divide-y divide-slate-200 text-sm"><thead class="bg-slate-50 text-left text-xs font-semibold text-slate-600"><tr><th class="px-4 py-3">Fixture</th><th>Bet</th><th>Bookmaker</th><th class="text-right">Stake</th><th class="text-right">Odds</th><th>Result</th><th class="text-right">P/L</th><th class="text-right pr-4">CLV</th></tr></thead><tbody class="divide-y divide-slate-100"><tr :for={b <- @bets} class="hover:bg-slate-50"><td class="px-4 py-3 font-medium"><.link navigate={~p"/fixtures/#{b.fixture_id}"} class="text-emerald-700"><%= fixture_name(b.fixture) %></.link><div class="text-xs text-slate-500"><%= short_datetime(b.fixture.kickoff_at) %></div></td><td><%= b.market.name %> · <%= b.selection.name %></td><td><%= b.bookmaker.name %></td><td class="text-right tabular-nums"><%= currency(b.stake) %></td><td class="text-right tabular-nums"><%= odds(b.odds_taken) %></td><td><.status_badge status={b.result || b.status}/></td><td class="text-right font-semibold tabular-nums"><%= profit(b.profit_loss) %></td><td class="text-right pr-4 tabular-nums"><%= percent(b.clv_percentage) %></td></tr></tbody></table></div>
    <div class="space-y-3 md:hidden"><article :for={b <- @bets} class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"><div class="flex justify-between"><h2 class="font-bold"><%= fixture_name(b.fixture) %></h2><.status_badge status={b.result || b.status}/></div><p class="text-sm text-slate-600"><%= b.market.name %> · <%= b.selection.name %> · <%= b.bookmaker.name %></p><div class="mt-3 grid grid-cols-3 gap-2 text-sm"><span>Stake <b><%= currency(b.stake) %></b></span><span>Odds <b><%= odds(b.odds_taken) %></b></span><span>P/L <b><%= profit(b.profit_loss) %></b></span></div></article></div>
    </section>
    """
  end

  defp load_bets do
    bets =
      Repo.all(
        from(b in Bet,
          where: b.status in ["accepted", "placed", "settled", "pending"],
          order_by: [desc: b.placed_at, desc: b.id],
          preload: [fixture: [:home_team, :away_team], market: [], selection: [], bookmaker: []],
          limit: 50
        )
      )

    {bets, nil}
  rescue
    e in [DBConnection.ConnectionError, Ecto.QueryError, Postgrex.Error] ->
      Logger.error("Bets load failed: #{Exception.message(e)}")
      {[], "Please retry after the database connection recovers."}
  end

  defp fixture_name(nil), do: "Unknown fixture"
  defp fixture_name(f), do: "#{f.home_team.name} vs #{f.away_team.name}"

  defp perf(bets) do
    staked = Enum.reduce(bets, Decimal.new(0), &Decimal.add(&2, &1.stake || Decimal.new(0)))
    pl = Enum.reduce(bets, Decimal.new(0), &Decimal.add(&2, &1.profit_loss || Decimal.new(0)))

    open =
      Enum.filter(bets, &(&1.result in [nil, ""] and &1.status != "settled"))
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.stake || Decimal.new(0)))

    won = Enum.count(bets, &(&1.result == "won"))
    settled = Enum.count(bets, &(&1.result in ["won", "lost", "void"]))

    %{
      staked: staked,
      pl: pl,
      open: open,
      roi:
        if(Decimal.compare(staked, 0) == :gt,
          do: percent(Decimal.mult(Decimal.div(pl, staked), 100)),
          else: "—"
        ),
      win_rate: if(settled > 0, do: "#{round(won / settled * 100)}%", else: "—"),
      settled: "#{settled}/#{length(bets)}"
    }
  end
end

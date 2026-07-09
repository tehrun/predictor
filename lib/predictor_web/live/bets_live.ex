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
    <section class="mx-auto max-w-7xl space-y-8 px-4 py-6 sm:px-6 sm:py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">Bets</p>
        <h1 class="text-3xl font-bold text-slate-900">Tracked accepted bets</h1>
        <p class="text-slate-600">
          Settled and in-flight accepted bets with result, profit/loss, and closing-line value.
        </p>
      </header>

      <div :if={Enum.empty?(@bets)} class="rounded-xl border border-dashed border-slate-300 bg-white px-4 py-10 text-center text-sm text-slate-500 shadow-sm">
        No accepted bets are being tracked yet.
      </div>

      <div :if={@bets != []} class="hidden overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm md:block">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
              <tr>
                <th class="px-5 py-3">Placed</th>
                <th class="px-5 py-3">Fixture</th>
                <th class="px-5 py-3">Market</th>
                <th class="px-5 py-3">Selection</th>
                <th class="px-5 py-3">Bookmaker</th>
                <th class="px-5 py-3 text-right">Stake</th>
                <th class="px-5 py-3 text-right">Odds</th>
                <th class="px-5 py-3">Result</th>
                <th class="px-5 py-3 text-right">P/L</th>
                <th class="px-5 py-3 text-right">CLV</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 bg-white">
              <tr :for={bet <- @bets} class="align-top transition hover:bg-slate-50/80">
                <td class="whitespace-nowrap px-5 py-4 text-slate-600">{format_datetime(bet.placed_at)}</td>
                <td class="px-5 py-4 font-medium text-slate-900">
                  <.link navigate={~p"/fixtures/#{bet.fixture_id}"} class="text-emerald-700 hover:underline">
                    {fixture_name(bet.fixture)}
                  </.link>
                </td>
                <td class="whitespace-nowrap px-5 py-4 text-slate-700">{bet.market.name}</td>
                <td class="whitespace-nowrap px-5 py-4 text-slate-700">{bet.selection.name}</td>
                <td class="whitespace-nowrap px-5 py-4 text-slate-700">{bet.bookmaker.name}</td>
                <td class="whitespace-nowrap px-5 py-4 text-right text-slate-700">{format_decimal(bet.stake)}</td>
                <td class="whitespace-nowrap px-5 py-4 text-right text-slate-700">{format_decimal(bet.odds_taken)}</td>
                <td class="whitespace-nowrap px-5 py-4"><.status_badge value={bet.result || bet.status} /></td>
                <td class={[
                  "whitespace-nowrap px-5 py-4 text-right font-semibold tabular-nums",
                  profit_class(bet.profit_loss)
                ]}>{format_profit_loss(bet.profit_loss)}</td>
                <td class="whitespace-nowrap px-5 py-4 text-right text-slate-700 tabular-nums">{format_percent(bet.clv_percentage)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div :if={@bets != []} class="space-y-4 md:hidden">
        <article :for={bet <- @bets} class="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0 space-y-1">
              <p class="text-xs font-medium uppercase tracking-wide text-slate-500">{format_datetime(bet.placed_at)}</p>
              <.link navigate={~p"/fixtures/#{bet.fixture_id}"} class="block font-semibold text-emerald-700 hover:underline">
                {fixture_name(bet.fixture)}
              </.link>
              <p class="text-sm text-slate-600">{bet.market.name} · {bet.bookmaker.name}</p>
            </div>
            <.status_badge value={bet.result || bet.status} />
          </div>

          <dl class="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">Selection</dt>
              <dd class="mt-1 font-medium text-slate-900">{bet.selection.name}</dd>
            </div>
            <div class="text-right">
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">Odds</dt>
              <dd class="mt-1 text-slate-900 tabular-nums">{format_decimal(bet.odds_taken)}</dd>
            </div>
            <div>
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">Stake</dt>
              <dd class="mt-1 text-slate-900 tabular-nums">{format_decimal(bet.stake)}</dd>
            </div>
            <div class="text-right">
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">P/L</dt>
              <dd class={["mt-1 font-semibold tabular-nums", profit_class(bet.profit_loss)]}>{format_profit_loss(bet.profit_loss)}</dd>
            </div>
            <div>
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">Result</dt>
              <dd class="mt-1"><.status_badge value={bet.result || bet.status} /></dd>
            </div>
            <div class="text-right">
              <dt class="text-xs font-medium uppercase tracking-wide text-slate-500">CLV</dt>
              <dd class="mt-1 text-slate-900 tabular-nums">{format_percent(bet.clv_percentage)}</dd>
            </div>
          </dl>
        </article>
      </div>
    </section>
    """
  end

  attr(:value, :string, default: nil)

  defp status_badge(assigns) do
    ~H"""
    <span class={["inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold capitalize", badge_class(@value)]}>
      {format_status(@value)}
    </span>
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

  defp format_profit_loss(nil), do: "—"

  defp format_profit_loss(decimal) do
    case Decimal.compare(decimal, 0) do
      :lt -> format_decimal(decimal)
      _ -> "+#{format_decimal(decimal)}"
    end
  end

  defp format_status(nil), do: "Pending"

  defp format_status(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
  end

  defp badge_class(nil), do: "bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200"
  defp badge_class("accepted"), do: "bg-sky-50 text-sky-700 ring-1 ring-inset ring-sky-200"
  defp badge_class("placed"), do: "bg-amber-50 text-amber-700 ring-1 ring-inset ring-amber-200"
  defp badge_class("settled"), do: "bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200"
  defp badge_class("won"), do: "bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200"
  defp badge_class("win"), do: "bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200"
  defp badge_class("lost"), do: "bg-rose-50 text-rose-700 ring-1 ring-inset ring-rose-200"
  defp badge_class("loss"), do: "bg-rose-50 text-rose-700 ring-1 ring-inset ring-rose-200"
  defp badge_class("void"), do: "bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200"
  defp badge_class("push"), do: "bg-slate-100 text-slate-700 ring-1 ring-inset ring-slate-200"
  defp badge_class(_value), do: "bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-200"
end

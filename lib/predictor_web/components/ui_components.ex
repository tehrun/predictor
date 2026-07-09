defmodule PredictorWeb.UIComponents do
  use Phoenix.Component
  import PredictorWeb.FormatHelpers

  use Phoenix.VerifiedRoutes,
    endpoint: PredictorWeb.Endpoint,
    router: PredictorWeb.Router,
    statics: PredictorWeb.static_paths()

  attr(:title, :string, required: true)
  attr(:eyebrow, :string, default: nil)
  attr(:description, :string, default: nil)
  slot(:actions)

  def page_header(assigns) do
    ~H"""
    <header class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div><p :if={@eyebrow} class="text-sm font-semibold text-emerald-700"><%= @eyebrow %></p><h1 class="text-3xl font-bold tracking-tight text-slate-950"><%= @title %></h1><p :if={@description} class="mt-1 max-w-3xl text-sm text-slate-600"><%= @description %></p></div>
      <div class="flex gap-2"><%= render_slot(@actions) %></div>
    </header>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :string, required: true)
  attr(:hint, :string, default: nil)
  attr(:tone, :string, default: "slate")

  def stat_card(assigns) do
    ~H"""
    <section class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"><p class="text-sm font-medium text-slate-500"><%= @label %></p><p class={["mt-2 text-3xl font-bold tabular-nums", tone_text(@tone)]}><%= @value %></p><p :if={@hint} class="mt-1 text-xs text-slate-500"><%= @hint %></p></section>
    """
  end

  attr(:status, :string, default: "running")

  def status_badge(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold", badge_class(@status)]}><span class="h-1.5 w-1.5 rounded-full bg-current"></span><%= String.capitalize(to_string(@status || "unknown")) %></span>
    """
  end

  attr(:last_update, DateTime, default: nil)
  attr(:compact, :boolean, default: false)

  def scanner_status(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-white p-4 text-sm shadow-sm"><div class="flex items-center justify-between"><span class="font-semibold text-slate-900">Scanner</span><.status_badge status={scanner_state(@last_update)} /></div><p class="mt-2 text-xs text-slate-500">Last update: <span class="tabular-nums"><%= short_datetime(@last_update) %></span></p><p class="text-xs text-slate-500">Next scan: <%= next_scan(@last_update) %></p></div>
    """
  end

  attr(:title, :string, required: true)
  attr(:message, :string, required: true)
  attr(:action, :string, default: nil)
  attr(:href, :string, default: nil)

  def empty_state(assigns) do
    ~H"""
    <section class="rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"><div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-slate-100 text-2xl">⌁</div><h2 class="text-lg font-semibold text-slate-900"><%= @title %></h2><p class="mx-auto mt-2 max-w-xl text-sm text-slate-600"><%= @message %></p><.link :if={@action && @href} navigate={@href} class="mt-5 inline-flex rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white"><%= @action %></.link></section>
    """
  end

  attr(:rec, :map, required: true)

  def recommendation_card(assigns) do
    ~H"""
    <div class="rounded-2xl border border-emerald-200 bg-emerald-50/60 p-4"><div class="flex flex-wrap items-start justify-between gap-3"><div><p class="text-sm text-slate-600"><%= @rec.market.name %> · <%= @rec.selection.name %></p><p class="mt-1 text-xl font-bold text-slate-950"><%= @rec.bookmaker.name %> at <span class="tabular-nums"><%= odds(@rec.odds) %></span></p></div><span class="rounded-full bg-emerald-600 px-3 py-1 text-sm font-bold text-white"><%= ev(@rec.ev_percentage) %></span></div><dl class="mt-4 grid grid-cols-2 gap-3 text-sm md:grid-cols-5"><div><dt class="text-slate-500">Fair odds</dt><dd class="font-semibold tabular-nums"><%= odds(@rec.fair_odds) %></dd></div><div><dt class="text-slate-500">Implied</dt><dd class="font-semibold tabular-nums"><%= probability(implied(@rec.odds)) %></dd></div><div><dt class="text-slate-500">Fair prob.</dt><dd class="font-semibold tabular-nums"><%= probability(@rec.fair_probability) %></dd></div><div><dt class="text-slate-500">Confidence</dt><dd class="font-semibold"><%= confidence_label(@rec.confidence_score) %></dd></div><div><dt class="text-slate-500">Stake</dt><dd class="font-semibold tabular-nums"><%= currency(@rec.recommended_stake) %></dd></div></dl></div>
    """
  end

  attr(:fixture, :map, required: true)
  attr(:recommendations, :list, required: true)

  def fixture_card(assigns) do
    assigns = assign(assigns, :best, hd(assigns.recommendations))

    ~H"""
    <article class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm"><header class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"><div><p class="text-sm font-medium text-slate-500"><%= @fixture.league.name %> · <span title={datetime(@fixture.kickoff_at)}><%= short_datetime(@fixture.kickoff_at) %></span> · <%= relative(@fixture.kickoff_at) %></p><h2 class="mt-1 text-xl font-bold text-slate-950"><%= @fixture.home_team.name %> vs <%= @fixture.away_team.name %></h2></div><div class="flex items-center gap-2"><.status_badge status={@fixture.status} /><span class="rounded-full bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-700"><%= length(@recommendations) %> opportunities</span></div></header><div class="mt-5"><.recommendation_card rec={@best}/></div><details class="mt-4"><summary class="cursor-pointer text-sm font-semibold text-slate-700">Compare bookmakers and additional recommendations</summary><div class="mt-3 grid gap-2"><div :for={rec <- @recommendations} class="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-slate-50 px-3 py-2 text-sm"><span><%= rec.market.name %> · <%= rec.selection.name %> · <%= rec.bookmaker.name %></span><span class="font-semibold tabular-nums"><%= odds(rec.odds) %> · <%= ev(rec.ev_percentage) %></span></div></div></details><footer class="mt-5 flex flex-wrap gap-2"><.link navigate={~p"/fixtures/#{@fixture.id}"} class="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white">View fixture</.link><button class="rounded-xl border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700" phx-click="track_bet" phx-value-id={@best.id}>Track bet</button><button class="rounded-xl border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700" phx-click="dismiss" phx-value-id={@best.id}>Dismiss</button></footer></article>
    """
  end

  def scanner_state(nil), do: "delayed"

  def scanner_state(dt),
    do: if(DateTime.diff(DateTime.utc_now(), dt, :minute) > 60, do: "delayed", else: "running")

  def next_scan(nil), do: "after first successful scan"
  def next_scan(dt), do: dt |> DateTime.add(15 * 60, :second) |> short_datetime()
  def implied(nil), do: nil
  def implied(%Decimal{} = odds), do: Decimal.div(Decimal.new(1), odds)
  defp tone_text("emerald"), do: "text-emerald-700"
  defp tone_text("rose"), do: "text-rose-700"
  defp tone_text("amber"), do: "text-amber-700"
  defp tone_text(_), do: "text-slate-950"

  defp badge_class(s) when s in ["running", "scheduled", "placed", "won", "settled"],
    do: "bg-emerald-50 text-emerald-700"

  defp badge_class(s) when s in ["lost", "error"], do: "bg-rose-50 text-rose-700"
  defp badge_class(s) when s in ["delayed", "paused", "pending"], do: "bg-amber-50 text-amber-700"
  defp badge_class(_), do: "bg-slate-100 text-slate-700"
end

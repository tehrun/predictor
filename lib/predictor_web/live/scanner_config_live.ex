defmodule PredictorWeb.ScannerConfigLive do
  use PredictorWeb, :live_view

  alias Predictor.Scanner.Config, as: ScannerConfig

  @impl true
  def mount(_params, _session, socket) do
    setting = ScannerConfig.get_setting()
    changeset = ScannerConfig.change_setting(setting)

    {:ok,
     socket
     |> assign(:page_title, "Scanner settings")
     |> assign(:setting, setting)
     |> assign_form(changeset)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-5xl space-y-8 px-6 py-8">
      <header class="space-y-2">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-600">Settings</p>
        <h1 class="text-3xl font-bold text-slate-900">Scanner runtime configuration</h1>
        <p class="text-slate-600">
          Tune scanner filters, value thresholds, staking defaults, and alert thresholds without redeploying.
          Saved values apply to future odds-ingestion and recommendation jobs.
        </p>
        <div class="rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-900">
          <p class="font-semibold">API budget reminder</p>
          <p>
            Changing these settings does not call The Odds API. Keep server cron conservative while using a limited monthly request plan.
          </p>
        </div>
      </header>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        class="space-y-8 rounded-xl border border-slate-200 bg-white p-6 shadow-sm"
      >
        <.settings_group
          title="Enabled sources and filters"
          description="Choose which sports, leagues, markets, and bookmakers the scanner can consider. Blank list fields mean “allow all”."
        >
          <div class="grid gap-6 md:grid-cols-2">
            <.field
              form={@form}
              field={:enabled_sports}
              label="Enabled sports"
              help="Comma-separated slugs. Blank allows all. Example: football"
            />
            <.field
              form={@form}
              field={:enabled_leagues}
              label="Enabled leagues"
              help="Comma-separated league slugs. Blank allows all."
            />
            <.field
              form={@form}
              field={:enabled_markets}
              label="Enabled markets"
              help="Comma-separated market keys. Example: 1x2"
            />
            <.field
              form={@form}
              field={:enabled_bookmakers}
              label="Enabled bookmakers"
              help="Comma-separated bookmaker slugs. Blank allows all."
            />
            <.field
              form={@form}
              field={:sharp_reference_source}
              label="Sharp reference bookmaker"
              help="Bookmaker slug used for fair-odds generation. Example: pinnacle"
            />
          </div>
        </.settings_group>

        <.settings_group
          title="Thresholds and staking values"
          description="Control the recommendation cutoffs, odds bounds, and bankroll sizing defaults stored with generated recommendations."
        >
          <div class="grid gap-6 md:grid-cols-3">
            <.field
              form={@form}
              field={:minimum_ev_threshold}
              label="Minimum EV"
              type="number"
              step="0.001"
              help="0.05 means +5% EV."
            />
            <.field
              form={@form}
              field={:minimum_confidence_threshold}
              label="Confidence score"
              type="number"
              step="0.01"
              help="Stored on generated recommendations, 0 to 1."
            />
            <.field
              form={@form}
              field={:minimum_odds}
              label="Minimum odds"
              type="number"
              step="0.01"
              help="Optional lower decimal-odds bound."
            />
            <.field
              form={@form}
              field={:maximum_odds}
              label="Maximum odds"
              type="number"
              step="0.01"
              help="Optional upper decimal-odds bound."
            />
            <.field
              form={@form}
              field={:kelly_fraction}
              label="Kelly fraction"
              type="number"
              step="0.01"
              help="0.25 = quarter Kelly."
            />
            <.field
              form={@form}
              field={:max_stake_percentage}
              label="Max stake percentage"
              type="number"
              step="0.001"
              help="0.01 = cap at 1% bankroll."
            />
          </div>
        </.settings_group>

        <.settings_group
          title="Alerts and frequency"
          description="Set alerting sensitivity and document the intended collection cadence for scheduled scanner jobs."
        >
          <div class="grid gap-6 md:grid-cols-2">
            <.field
              form={@form}
              field={:telegram_alert_threshold}
              label="Telegram alert EV"
              type="number"
              step="0.001"
              help="Minimum EV before alerting."
            />
            <.field
              form={@form}
              field={:odds_collection_frequency_seconds}
              label="Collection frequency seconds"
              type="number"
              help="Informational unless scheduler code/cron uses it. 21600 = 6 hours."
            />
          </div>
        </.settings_group>

        <div class="flex flex-col gap-4 border-t border-slate-200 pt-6 md:flex-row md:items-center md:justify-between">
          <p class="text-sm leading-6 text-slate-500">
            Blank list fields mean “allow all”. Optional odds fields may stay blank.
          </p>
          <button
            type="submit"
            class="w-full rounded-lg bg-emerald-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700 md:w-auto"
          >
            Save scanner settings
          </button>
        </div>
      </.form>
    </section>
    """
  end

  @impl true
  def handle_event("validate", %{"setting" => params}, socket) do
    changeset =
      socket.assigns.setting
      |> ScannerConfig.change_setting(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"setting" => params}, socket) do
    case ScannerConfig.save_setting(params) do
      {:ok, setting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Scanner settings saved.")
         |> assign(:setting, setting)
         |> assign_form(ScannerConfig.change_setting(setting))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  attr(:form, :map, required: true)
  attr(:field, :atom, required: true)
  attr(:label, :string, required: true)
  attr(:type, :string, default: "text")
  attr(:step, :string, default: nil)
  attr(:help, :string, default: nil)

  defp field(assigns) do
    ~H"""
    <div class="space-y-2">
      <label for={@form[@field].id} class="block text-sm font-semibold text-slate-700">{@label}</label>
      <input
        id={@form[@field].id}
        name={@form[@field].name}
        type={@type}
        step={@step}
        value={Phoenix.HTML.Form.normalize_value(@type, @form[@field].value)}
        class="block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500"
      />
      <p :if={@help} class="text-xs leading-5 text-slate-400">{@help}</p>
      <p :for={error <- errors_for(@form, @field)} class="text-xs font-medium text-rose-700">{error}</p>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:description, :string, required: true)
  slot(:inner_block, required: true)

  defp settings_group(assigns) do
    ~H"""
    <section class="space-y-5 rounded-xl border border-slate-200 bg-slate-50/60 p-5">
      <header class="space-y-1">
        <h2 class="text-base font-semibold text-slate-900">{@title}</h2>
        <p class="text-sm leading-6 text-slate-500">{@description}</p>
      </header>
      <div class="rounded-lg border border-slate-200 bg-white p-5">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp errors_for(form, field) do
    form.source
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Map.get(field, [])
  end
end

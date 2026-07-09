defmodule PredictorWeb.SimplePageLive do
  use PredictorWeb, :live_view

  def mount(_, _, socket), do: {:ok, socket}

  def handle_params(_, _, socket) do
    title =
      case socket.assigns.live_action do
        :fixtures -> "Fixtures"
        :performance -> "Performance"
        :status -> "System Status"
        _ -> "Opportunities"
      end

    {:noreply, assign(socket, page_title: title, last_odds_update: nil)}
  end

  def render(assigns) do
    ~H"""
    <section class="space-y-6">
      <.page_header
        title={@page_title}
        eyebrow="BSharp"
        description="This section is part of the redesigned application shell and will expand as data workflows mature."
      />
      <.empty_state
        title="Coming into focus"
        message="Use the dashboard and fixture detail pages for the redesigned betting workflow in this iteration."
        action="Back to dashboard"
        href={~p"/dashboard"}
      />
    </section>
    """
  end
end

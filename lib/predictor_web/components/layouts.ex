defmodule PredictorWeb.Layouts do
  use PredictorWeb, :html
  embed_templates("layouts/*")

  attr(:href, :string, required: true)
  attr(:label, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:current, :boolean, default: false)

  def nav_item(assigns) do
    ~H"""
    <.link navigate={@href} aria-current={if @current, do: "page", else: nil} class={["mb-1 flex items-center gap-3 rounded-xl px-3 py-2.5 transition focus:outline-none focus:ring-2 focus:ring-emerald-500", @current && "bg-emerald-50 text-emerald-800", !@current && "text-slate-600 hover:bg-slate-100 hover:text-slate-950"]}><span class="w-5 text-center"><%= @icon %></span><%= @label %></.link>
    """
  end
end

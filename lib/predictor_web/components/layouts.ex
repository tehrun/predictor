defmodule PredictorWeb.Layouts do
  use PredictorWeb, :html

  def on_mount(:default, _params, _session, socket) do
    socket =
      Phoenix.LiveView.attach_hook(socket, :current_path, :handle_params, fn _params,
                                                                             uri,
                                                                             socket ->
        {:cont, Phoenix.Component.assign(socket, :current_path, URI.parse(uri).path)}
      end)

    {:cont, socket}
  end

  attr(:to, :string, required: true)
  attr(:match_paths, :list, default: [])
  attr(:current, :any, required: true)
  slot(:inner_block, required: true)

  def nav_link(assigns) do
    assigns =
      assigns
      |> assign(:active?, active_link?(assigns.current, assigns.to, assigns.match_paths))
      |> assign(
        :class,
        nav_link_class(active_link?(assigns.current, assigns.to, assigns.match_paths))
      )

    ~H"""
    <.link navigate={@to} class={@class} aria-current={if @active?, do: "page", else: nil}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp active_link?(current_assigns, to, match_paths) do
    current_path = current_path(current_assigns)
    paths = Enum.uniq([to | match_paths])

    is_binary(current_path) and current_path in paths
  end

  defp current_path(%{} = assigns) do
    cond do
      is_binary(assigns[:current_path]) ->
        assigns.current_path

      is_binary(assigns[:uri]) ->
        URI.parse(assigns.uri).path

      match?(%Plug.Conn{}, assigns[:conn]) ->
        assigns.conn.request_path

      true ->
        nil
    end
  end

  defp nav_link_class(true) do
    [
      "rounded-full bg-emerald-50 px-3 py-2 text-emerald-700",
      "shadow-sm shadow-emerald-100/50"
    ]
  end

  defp nav_link_class(false) do
    [
      "rounded-full px-3 py-2 text-slate-700 transition",
      "hover:bg-emerald-50 hover:text-emerald-700"
    ]
  end

  embed_templates("layouts/*")
end

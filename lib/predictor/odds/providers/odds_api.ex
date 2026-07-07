defmodule Predictor.Odds.Providers.OddsAPI do
  @moduledoc """
  MVP adapter for The Odds API football odds.

  The provider is intentionally narrow: it fetches soccer events plus 1X2 (`h2h`)
  odds for configured bookmakers and returns normalized data for the collection
  worker. Scheduling should remain disabled until rate limits and provider costs
  are reviewed for the configured API key.
  """

  @behaviour Predictor.Odds.Provider

  @base_url "https://api.the-odds-api.com/v4"
  @provider "odds_api"
  @market_key "h2h"

  @impl true
  def fetch_fixtures(opts \\ []) do
    with {:ok, api_key} <- api_key(opts) do
      sport_key = Keyword.get(opts, :sport_key, config(:sport_key, "soccer_epl"))
      request(@base_url <> "/sports/#{sport_key}/events", api_key, [])
    end
  end

  @impl true
  def fetch_odds(opts \\ []) do
    with {:ok, api_key} <- api_key(opts) do
      sport_key = Keyword.get(opts, :sport_key, config(:sport_key, "soccer_epl"))

      query =
        [
          regions: Keyword.get(opts, :regions, config(:regions, "uk")),
          markets: @market_key,
          oddsFormat: "decimal"
        ]
        |> maybe_put(:bookmakers, Keyword.get(opts, :bookmakers, config(:bookmakers)))

      request(@base_url <> "/sports/#{sport_key}/odds", api_key, query)
    end
  end

  @impl true
  def normalize_fixture(%{} = event) do
    %{
      provider: @provider,
      external_id: event["id"],
      sport: %{
        name: "Football",
        slug: "football",
        external_provider: @provider,
        external_id: event["sport_key"]
      },
      league: %{
        name: event["sport_title"] || event["sport_key"] || "Football",
        slug: slugify(event["sport_key"] || event["sport_title"] || "football"),
        external_provider: @provider,
        external_id: event["sport_key"]
      },
      home_team: normalize_team(event["home_team"], event["sport_key"]),
      away_team: normalize_team(event["away_team"], event["sport_key"]),
      kickoff_at: parse_datetime(event["commence_time"]),
      status: "scheduled"
    }
  end

  @impl true
  def normalize_market(%{"key" => @market_key} = market),
    do: %{name: "Full Time Result", key: "1x2", description: market["last_update"]}

  def normalize_market(%{"key" => key} = market),
    do: %{name: market["name"] || key, key: key, description: market["last_update"]}

  @impl true
  def normalize_selection(%{"name" => name} = outcome) do
    key = selection_key(name, outcome)

    %{
      name: selection_name(key, name),
      key: key,
      sort_order: selection_order(key),
      price: outcome["price"]
    }
  end

  def normalize_bookmaker(%{} = bookmaker) do
    %{
      name: bookmaker["title"] || bookmaker["key"],
      slug: slugify(bookmaker["key"] || bookmaker["title"]),
      external_provider: @provider,
      external_id: bookmaker["key"]
    }
  end

  def provider_name, do: @provider

  defp request(url, api_key, query) do
    request =
      Finch.build(:get, url <> "?" <> URI.encode_query(Keyword.put(query, :apiKey, api_key)))

    case Finch.request(request, Predictor.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key(opts) do
    case Keyword.get(opts, :api_key, config(:api_key) || external_api_key()) do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp config(key, default \\ nil),
    do: Application.get_env(:predictor, __MODULE__, []) |> Keyword.get(key, default)

  defp external_api_key, do: Application.get_env(:predictor, :external_apis, [])[:odds_api_key]

  defp normalize_team(name, sport_key),
    do: %{
      name: name,
      slug: slugify(name),
      external_provider: @provider,
      external_id: [sport_key, name] |> Enum.reject(&is_nil/1) |> Enum.join(":")
    }

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp maybe_put(query, _key, nil), do: query
  defp maybe_put(query, _key, ""), do: query
  defp maybe_put(query, key, value), do: Keyword.put(query, key, value)
  defp selection_key("Draw", _), do: "draw"
  defp selection_key(name, %{"description" => home}) when name == home, do: "home"

  defp selection_key(name, _),
    do: if(String.downcase(to_string(name)) == "draw", do: "draw", else: "away")

  defp selection_name("home", _), do: "Home"
  defp selection_name("draw", _), do: "Draw"
  defp selection_name("away", _), do: "Away"
  defp selection_order("home"), do: 1
  defp selection_order("draw"), do: 2
  defp selection_order("away"), do: 3

  defp slugify(value),
    do:
      value
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
end

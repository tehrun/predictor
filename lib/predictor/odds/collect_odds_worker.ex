defmodule Predictor.Odds.CollectOddsWorker do
  @moduledoc """
  Collects upcoming football fixtures and 1X2 odds snapshots from a configured provider.

  This worker is safe to enqueue manually. Do not add a periodic Oban schedule until
  provider rate limits and costs have been reviewed for the selected provider/API key.
  """

  use Oban.Worker, queue: :odds, max_attempts: 3

  require Logger

  alias Predictor.Catalog.{Bookmaker, Fixture, League, Sport, Team}
  alias Predictor.Markets.{Market, Selection}
  alias Predictor.Odds.{OddsSnapshot, Providers.OddsAPI}
  alias Predictor.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    provider = provider_module(args)
    opts = provider_opts(args)

    with {:fixtures, {:ok, fixtures}} <- {:fixtures, provider.fetch_fixtures(opts)},
         {:odds, {:ok, odds_events}} <- {:odds, provider.fetch_odds(opts)} do
      Enum.each(fixtures, &upsert_fixture(provider, &1))
      Enum.each(odds_events, &persist_odds_event(provider, &1))
      :ok
    else
      {stage, {:error, reason}} ->
        Logger.error(
          "Odds provider #{inspect(provider)} failed during #{stage}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp persist_odds_event(provider, event) do
    try do
      fixture = upsert_fixture(provider, event)

      event
      |> Map.get("bookmakers", [])
      |> Enum.each(fn bookmaker_payload ->
        with {:ok, bookmaker} <- upsert_bookmaker(provider.normalize_bookmaker(bookmaker_payload)) do
          bookmaker_payload
          |> Map.get("markets", [])
          |> Enum.filter(&(&1["key"] == "h2h"))
          |> Enum.each(&persist_market(provider, fixture, bookmaker, &1))
        end
      end)
    rescue
      exception ->
        Logger.error(
          "Failed to persist odds for provider event #{inspect(event["id"])}: #{Exception.message(exception)}"
        )
    end
  end

  defp persist_market(provider, fixture, bookmaker, market_payload) do
    with {:ok, market} <-
           upsert_market(provider.normalize_market(market_payload), fixture.league.sport_id) do
      market_payload
      |> Map.get("outcomes", [])
      |> Enum.each(fn outcome ->
        selection_attrs =
          provider.normalize_selection(Map.put(outcome, "description", fixture.home_team.name))

        with {:ok, selection} <- upsert_selection(selection_attrs, market.id) do
          insert_snapshot(
            fixture,
            bookmaker,
            market,
            selection,
            selection_attrs,
            market_payload,
            provider
          )
        end
      end)
    end
  end

  defp insert_snapshot(
         fixture,
         bookmaker,
         market,
         selection,
         selection_attrs,
         market_payload,
         provider
       ) do
    captured_at =
      parse_datetime(market_payload["last_update"]) ||
        DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      fixture_id: fixture.id,
      bookmaker_id: bookmaker.id,
      market_id: market.id,
      selection_id: selection.id,
      decimal_odds: Decimal.new(to_string(selection_attrs.price)),
      captured_at: captured_at,
      external_provider: provider.provider_name(),
      external_id:
        Enum.join(
          [
            fixture.external_id,
            bookmaker.external_id,
            market.key,
            selection.key,
            DateTime.to_iso8601(captured_at)
          ],
          ":"
        )
    }

    %OddsSnapshot{}
    |> OddsSnapshot.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:external_provider, :external_id])
  end

  defp upsert_fixture(provider, payload) do
    attrs = provider.normalize_fixture(payload)
    {:ok, sport} = upsert_sport(attrs.sport)
    {:ok, league} = upsert_league(Map.put(attrs.league, :sport_id, sport.id))
    {:ok, home_team} = upsert_team(Map.put(attrs.home_team, :sport_id, sport.id))
    {:ok, away_team} = upsert_team(Map.put(attrs.away_team, :sport_id, sport.id))

    fixture_attrs = %{
      league_id: league.id,
      home_team_id: home_team.id,
      away_team_id: away_team.id,
      kickoff_at: attrs.kickoff_at,
      status: attrs.status,
      external_provider: attrs.provider,
      external_id: attrs.external_id
    }

    {:ok, fixture} =
      upsert_and_get(Fixture, Fixture.changeset(%Fixture{}, fixture_attrs),
        external_provider: attrs.provider,
        external_id: attrs.external_id
      )

    Repo.preload(fixture, [:home_team, league: :sport])
  end

  defp upsert_sport(attrs),
    do: upsert_and_get(Sport, Sport.changeset(%Sport{}, attrs), slug: attrs.slug)

  defp upsert_league(attrs),
    do:
      upsert_and_get(League, League.changeset(%League{}, attrs),
        external_provider: attrs.external_provider,
        external_id: attrs.external_id
      )

  defp upsert_team(attrs),
    do:
      upsert_and_get(Team, Team.changeset(%Team{}, attrs),
        external_provider: attrs.external_provider,
        external_id: attrs.external_id
      )

  defp upsert_bookmaker(attrs),
    do: upsert_and_get(Bookmaker, Bookmaker.changeset(%Bookmaker{}, attrs), slug: attrs.slug)

  defp upsert_market(attrs, sport_id),
    do:
      upsert_and_get(Market, Market.changeset(%Market{}, Map.put(attrs, :sport_id, sport_id)),
        sport_id: sport_id,
        key: attrs.key
      )

  defp upsert_selection(attrs, market_id),
    do:
      upsert_and_get(
        Selection,
        Selection.changeset(%Selection{}, Map.put(attrs, :market_id, market_id)),
        market_id: market_id,
        key: attrs.key
      )

  defp upsert_and_get(schema, changeset, where) do
    case Repo.insert(changeset, on_conflict: :nothing) do
      {:ok, %{id: nil}} -> {:ok, Repo.get_by!(schema, where)}
      {:ok, struct} -> {:ok, struct}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp provider_module(%{"provider" => "odds_api"}), do: OddsAPI
  defp provider_module(_args), do: Application.get_env(:predictor, :odds_provider, OddsAPI)

  defp provider_opts(args) do
    args
    |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
    |> Keyword.drop([:provider])
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end

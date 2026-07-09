defmodule Predictor.Value.SharpOddsEngine do
  @moduledoc """
  Builds deterministic fair 1X2 prices from a configured sharp reference bookmaker.

  The MVP removes the sharp source's overround by converting decimal odds to raw
  implied probabilities, normalizing those probabilities to sum to one, and
  converting the normalized probabilities back to fair decimal odds.
  """

  import Ecto.Query

  alias Predictor.Catalog.Bookmaker
  alias Predictor.Markets.Market
  alias Predictor.Odds.OddsSnapshot
  alias Predictor.Repo
  alias Predictor.Scanner.Config, as: ScannerConfig
  alias Predictor.Value.FairOdd

  @source_engine "sharp_odds_engine"
  @market_key "1x2"

  @doc """
  Calculates fair probabilities and fair odds from decimal odds.

  The input can be any enumerable of maps/structs with `:selection_id` and
  `:decimal_odds` keys. Output order matches input order.
  """
  def calculate_fair_odds(odds_rows) do
    rows = Enum.map(odds_rows, &normalize_odds_row/1)

    raw_sum =
      rows
      |> Enum.map(& &1.raw_implied_probability)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    Enum.map(rows, fn row ->
      fair_probability = Decimal.div(row.raw_implied_probability, raw_sum)
      fair_odds = Decimal.div(Decimal.new(1), fair_probability)

      row
      |> Map.put(:fair_probability, fair_probability)
      |> Map.put(:fair_odds, fair_odds)
    end)
  end

  @doc """
  Reads the latest configured sharp 1X2 fixture odds and stores fair odds.

  Options:

    * `:bookmaker_slug` - overrides configured sharp reference bookmaker slug.
    * `:calculated_at` - deterministic timestamp for the rows (defaults to now).
  """
  def calculate_and_store_fair_odds(fixture_id, opts \\ []) do
    calculated_at = Keyword.get_lazy(opts, :calculated_at, &timestamp/0)

    with {:ok, bookmaker} <- reference_bookmaker(opts),
         {:ok, market} <- one_x_two_market(),
         snapshots when length(snapshots) == 3 <-
           latest_reference_odds(fixture_id, bookmaker.id, market.id) do
      snapshots
      |> calculate_fair_odds()
      |> Enum.map(&fair_odd_attrs(&1, fixture_id, market.id, calculated_at))
      |> Enum.map(&insert_fair_odd/1)
      |> collect_results()
    else
      [] ->
        {:error, :missing_reference_odds}

      snapshots when is_list(snapshots) ->
        {:error, {:incomplete_reference_odds, length(snapshots)}}

      {:error, _reason} = error ->
        error

      nil ->
        {:error, :missing_1x2_market}
    end
  end

  defp reference_bookmaker(opts) do
    slug = Keyword.get(opts, :bookmaker_slug) || ScannerConfig.load().sharp_reference_source

    case slug && Repo.get_by(Bookmaker, slug: slug) do
      %Bookmaker{} = bookmaker -> {:ok, bookmaker}
      nil -> {:error, :missing_reference_bookmaker}
    end
  end

  defp one_x_two_market do
    case Repo.get_by(Market, key: @market_key) do
      %Market{} = market -> {:ok, market}
      nil -> {:error, :missing_1x2_market}
    end
  end

  defp latest_reference_odds(fixture_id, bookmaker_id, market_id) do
    from(o in OddsSnapshot,
      where:
        o.fixture_id == ^fixture_id and o.bookmaker_id == ^bookmaker_id and
          o.market_id == ^market_id,
      distinct: o.selection_id,
      order_by: [asc: o.selection_id, desc: o.captured_at, desc: o.id]
    )
    |> Repo.all()
  end

  defp normalize_odds_row(row) do
    decimal_odds = decimal_value(Map.fetch!(row, :decimal_odds))

    %{
      selection_id: Map.fetch!(row, :selection_id),
      decimal_odds: decimal_odds,
      raw_implied_probability: Decimal.div(Decimal.new(1), decimal_odds)
    }
  end

  defp decimal_value(%Decimal{} = decimal), do: decimal
  defp decimal_value(value), do: Decimal.new(to_string(value))

  defp fair_odd_attrs(row, fixture_id, market_id, calculated_at) do
    %{
      fixture_id: fixture_id,
      market_id: market_id,
      selection_id: row.selection_id,
      implied_probability: Decimal.round(row.fair_probability, 6),
      fair_odds: Decimal.round(row.fair_odds, 4),
      source_engine: @source_engine,
      calculated_at: calculated_at
    }
  end

  defp insert_fair_odd(attrs) do
    %FairOdd{}
    |> FairOdd.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:fixture_id, :market_id, :selection_id, :source_engine, :calculated_at]
    )
  end

  defp collect_results(results) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, fair_odd} -> fair_odd end)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp timestamp, do: DateTime.utc_now() |> DateTime.truncate(:second)
end

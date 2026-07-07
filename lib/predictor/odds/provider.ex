defmodule Predictor.Odds.Provider do
  @moduledoc """
  Behaviour for external odds providers.

  Providers fetch raw provider payloads and normalize them into maps that the odds
  collection pipeline can persist. The normalized shape intentionally mirrors the
  catalog and odds schemas while keeping provider-specific identifiers available
  for idempotency.
  """

  @type fetch_opts :: keyword()
  @type provider_result :: {:ok, list(map())} | {:error, term()}

  @callback fetch_fixtures(fetch_opts()) :: provider_result()
  @callback fetch_odds(fetch_opts()) :: provider_result()
  @callback normalize_fixture(map()) :: map()
  @callback normalize_market(map()) :: map()
  @callback normalize_selection(map()) :: map()
end

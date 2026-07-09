# Predictor

Predictor is a Phoenix + PostgreSQL application scaffold for sports-betting odds ingestion, value detection, arbitrage discovery, bankroll sizing, and Telegram notifications.

## Local setup

1. Copy `.env.example` to `.env` and fill in secrets.
2. Export the variables in your shell, or load them with your preferred dotenv tool.
3. Install dependencies with `mix setup` once Hex access is available. This creates the database, runs migrations, and seeds a small demo recommendation so the dashboard has data.
4. If dependencies are already installed, run `mix ecto.setup` to create/migrate/seed the local database.
5. Start Phoenix with `mix phx.server` or inside IEx with `iex -S mix phx.server`.

## Runtime environment variables

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Production PostgreSQL connection URL. |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_DB` | Local development/test PostgreSQL settings. |
| `POOL_SIZE` | Ecto connection pool size. |
| `SECRET_KEY_BASE` | Phoenix endpoint secret for production. |
| `PHX_HOST`, `PORT` | Endpoint host and port. |
| `ODDS_API_KEY` | Odds provider API key. |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | Telegram notification credentials. |
| `SCANNER_ENABLED_SPORTS` | Comma-separated enabled sport slugs; empty allows all sports. |
| `SCANNER_ENABLED_LEAGUES` | Comma-separated enabled league slugs; empty allows all leagues. |
| `SCANNER_ENABLED_MARKETS` | Comma-separated enabled market keys; empty allows all markets. |
| `SCANNER_ENABLED_BOOKMAKERS` | Comma-separated enabled bookmaker slugs; empty allows all bookmakers. |
| `SCANNER_SHARP_REFERENCE_SOURCE` | Bookmaker slug used as the sharp reference source; falls back to `SHARP_REFERENCE_BOOKMAKER_SLUG` or `pinnacle`. |
| `SCANNER_MINIMUM_EV_THRESHOLD` | Minimum expected-value threshold for recommendations. |
| `SCANNER_MINIMUM_CONFIDENCE_THRESHOLD` | Confidence score assigned to scanner recommendations. |
| `SCANNER_MINIMUM_ODDS`, `SCANNER_MAXIMUM_ODDS` | Optional decimal-odds bounds for scanner recommendations. |
| `SCANNER_KELLY_FRACTION` | Fractional Kelly multiplier used by scanner staking logic. |
| `SCANNER_MAX_STAKE_PERCENTAGE` | Maximum stake percentage used by scanner staking logic. |
| `SCANNER_TELEGRAM_ALERT_THRESHOLD` | Minimum EV threshold for Telegram scanner alerts. |
| `SCANNER_ODDS_COLLECTION_FREQUENCY_SECONDS` | Odds collection cadence in seconds. |

## Application layout

* `lib/predictor/odds/` - odds ingestion and normalization.
* `lib/predictor/value/` - fair-odds and expected value logic.
* `lib/predictor/arbitrage/` - arbitrage detection.
* `lib/predictor/bankroll/` - Kelly and fractional Kelly staking.
* `lib/predictor/notifications/` - Telegram alerts.
* `lib/predictor_web/live/` - LiveView dashboard pages.

The health check endpoint is available at `GET /health`.

## Scanner settings page

The scanner can be tuned from the dashboard at `/settings/scanner`. Saved values are persisted in the `scanner_settings` table and override the runtime environment defaults for future odds ingestion and recommendation jobs. Blank enabled-list fields mean all sports/leagues/markets/bookmakers are allowed.

## Real-money recommendation guardrails

Outputs are informational only and are not guaranteed to produce profit. Before any real-money use, create an explicit bankroll configuration with user-supplied bankroll amount, currency, daily/weekly/monthly recommended stake limits, and a per-bet maximum stake cap. Optional cooldown settings can suppress recommendations after a configured number of consecutive losses.

The system records an audit trail for generated recommendations and accepted bets. Odds-provider Terms of Service must be reviewed for scraping, storage, and redistribution before storing or sharing provider odds beyond permitted use. Jurisdiction-specific legal review is required before building or enabling any bet-placement automation.

Automated betting should remain disabled until the strategy has demonstrated positive closing-line value and all legal/provider requirements are understood and documented.

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

## Application layout

* `lib/predictor/odds/` - odds ingestion and normalization.
* `lib/predictor/value/` - fair-odds and expected value logic.
* `lib/predictor/arbitrage/` - arbitrage detection.
* `lib/predictor/bankroll/` - Kelly and fractional Kelly staking.
* `lib/predictor/notifications/` - Telegram alerts.
* `lib/predictor_web/live/` - LiveView dashboard pages.

The health check endpoint is available at `GET /health`.

## Real-money recommendation guardrails

Outputs are informational only and are not guaranteed to produce profit. Before any real-money use, create an explicit bankroll configuration with user-supplied bankroll amount, currency, daily/weekly/monthly recommended stake limits, and a per-bet maximum stake cap. Optional cooldown settings can suppress recommendations after a configured number of consecutive losses.

The system records an audit trail for generated recommendations and accepted bets. Odds-provider Terms of Service must be reviewed for scraping, storage, and redistribution before storing or sharing provider odds beyond permitted use. Jurisdiction-specific legal review is required before building or enabling any bet-placement automation.

Automated betting should remain disabled until the strategy has demonstrated positive closing-line value and all legal/provider requirements are understood and documented.

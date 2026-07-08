import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://#{URI.encode_www_form(System.get_env("POSTGRES_USER", "predictor"))}:#{URI.encode_www_form(System.fetch_env!("POSTGRES_PASSWORD"))}@#{System.get_env("POSTGRES_HOST", "db")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "predictor_prod")}"

  secret_key_base = System.fetch_env!("SECRET_KEY_BASE")
  host = System.get_env("PHX_HOST", "example.com")
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :predictor, Predictor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("ECTO_SSL", "false") == "true"

  config :predictor, PredictorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: true
end

config :predictor, :external_apis,
  odds_api_key: System.get_env("ODDS_API_KEY"),
  telegram_bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  telegram_chat_id: System.get_env("TELEGRAM_CHAT_ID")

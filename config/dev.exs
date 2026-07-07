import Config

config :predictor, Predictor.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "predictor_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :predictor, PredictorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "dev-secret-key-base-change-me-dev-secret-key-base-change-me-dev-secret-key-base",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:predictor, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:predictor, ~w(--watch)]}
  ]

config :predictor, PredictorWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/predictor_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :predictor, dev_routes: true

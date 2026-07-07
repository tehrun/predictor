import Config

config :predictor,
  ecto_repos: [Predictor.Repo],
  generators: [timestamp_type: :utc_datetime]

config :predictor, PredictorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PredictorWeb.ErrorHTML, json: PredictorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Predictor.PubSub,
  live_view: [signing_salt: "predictor-signing-salt"]

config :predictor, Oban,
  repo: Predictor.Repo,
  queues: [default: 10, odds: 10, notifications: 5],
  plugins: [Oban.Plugins.Pruner]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :swoosh, :api_client, Swoosh.ApiClient.Finch
config :swoosh, :finch_name, Predictor.Finch

config :esbuild,
  version: "0.25.4",
  predictor: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.1.7",
  predictor: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/app.css),
    cd: Path.expand("..", __DIR__)
  ]

import_config "#{config_env()}.exs"

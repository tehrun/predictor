defmodule Predictor.Repo do
  use Ecto.Repo,
    otp_app: :predictor,
    adapter: Ecto.Adapters.Postgres
end

defmodule Predictor.Markets.Market do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Catalog.Sport
  alias Predictor.Markets.Selection

  schema "markets" do
    field(:name, :string)
    field(:key, :string)
    field(:description, :string)

    belongs_to(:sport, Sport)
    has_many(:selections, Selection)

    timestamps(type: :utc_datetime)
  end

  def changeset(market, attrs) do
    market
    |> cast(attrs, [:sport_id, :name, :key, :description])
    |> validate_required([:sport_id, :name, :key])
    |> assoc_constraint(:sport)
    |> unique_constraint([:sport_id, :key])
  end
end

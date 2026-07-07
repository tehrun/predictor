defmodule Predictor.Markets.Selection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Predictor.Markets.Market

  schema "selections" do
    field(:name, :string)
    field(:key, :string)
    field(:sort_order, :integer, default: 0)

    belongs_to(:market, Market)

    timestamps(type: :utc_datetime)
  end

  def changeset(selection, attrs) do
    selection
    |> cast(attrs, [:market_id, :name, :key, :sort_order])
    |> validate_required([:market_id, :name, :key, :sort_order])
    |> assoc_constraint(:market)
    |> unique_constraint([:market_id, :key])
  end
end

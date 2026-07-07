defmodule Predictor.Catalog.Bookmaker do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmakers" do
    field(:name, :string)
    field(:slug, :string)
    field(:external_provider, :string)
    field(:external_id, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(bookmaker, attrs) do
    bookmaker
    |> cast(attrs, [:name, :slug, :external_provider, :external_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
    |> unique_constraint([:external_provider, :external_id])
  end
end

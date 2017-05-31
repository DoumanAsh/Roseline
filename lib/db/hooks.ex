defmodule Db.Hook do
  @moduledoc "Hook schema"
  use Ecto.Schema

  schema "hooks" do
    field :name, :string
    field :kanji, :string
    field :code, :string
    field :versions, {:map, :string}
  end

  def changeset(hook, params \\ %{}) do
    import Ecto.Changeset

    hook
    |> cast(params, [:name, :kanji, :code, :versions])
    |> validate_required([:name, :code])
    |> unique_constraint(:name)
  end

  def create_w_validation(name, code, kanji \\ nil, versions \\ %{}) do
    changeset(%Db.Hook{}, %{name: name, kanji: kanji, code: code, versions: versions})
  end
end

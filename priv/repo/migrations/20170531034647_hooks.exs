defmodule Db.Repo.Migrations.Hooks do
  use Ecto.Migration

  def change do
    create table(:hooks) do
      add :name, :string
      add :kanji, :string
      add :code, :string
      add :versions, {:map, :string}
    end
  end
end

defmodule Db.Repo.Migrations.Hooks do
  use Ecto.Migration

  def change do
    create table(:hooks) do
      add :id, :id, primary_key: true
      add :code, :string
      add :versions, {:map, :string}
    end
  end
end

defmodule TapGame.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :tap_count, :integer, default: 0, null: false
      add :game_started_at, :utc_datetime, null: false
      add :game_ended_at, :utc_datetime
      add :duration_seconds, :integer, default: 15

      timestamps(type: :utc_datetime)
    end

    create index(:game_sessions, [:user_id])
    create index(:game_sessions, [:game_started_at])
    create index(:game_sessions, [:tap_count])
  end
end

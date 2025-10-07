defmodule TapGame.Games.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "game_sessions" do
    field :tap_count, :integer, default: 0
    field :game_started_at, :utc_datetime
    field :game_ended_at, :utc_datetime
    field :duration_seconds, :integer, default: 15

    belongs_to :user, TapGame.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game_session, attrs) do
    game_session
    |> cast(attrs, [:user_id, :tap_count, :game_started_at, :game_ended_at, :duration_seconds])
    |> validate_required([:user_id, :game_started_at])
    |> validate_number(:tap_count, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end
end

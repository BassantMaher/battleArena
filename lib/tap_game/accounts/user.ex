defmodule TapGame.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :session_id, :string

    has_many :game_sessions, TapGame.Games.GameSession

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :session_id])
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 50)
    |> unique_constraint(:username)
  end
end

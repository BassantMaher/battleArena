defmodule TapGame.Games do
  @moduledoc """
  The Games context for managing game sessions and scores.
  """

  import Ecto.Query, warn: false
  alias TapGame.Repo
  alias TapGame.Games.GameSession
  alias TapGame.Accounts.User

  @doc """
  Creates a game session.
  """
  def create_game_session(attrs \\ %{}) do
    %GameSession{}
    |> GameSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game session.
  """
  def update_game_session(%GameSession{} = game_session, attrs) do
    game_session
    |> GameSession.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets the top scores (leaderboard).
  """
  def get_leaderboard(limit \\ 10) do
    from(gs in GameSession,
      join: u in User,
      on: gs.user_id == u.id,
      where: not is_nil(gs.game_ended_at),
      order_by: [desc: gs.tap_count],
      limit: ^limit,
      select: %{
        username: u.username,
        tap_count: gs.tap_count,
        game_started_at: gs.game_started_at,
        game_ended_at: gs.game_ended_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets recent game sessions for a specific game start time.
  """
  def get_game_sessions_by_start_time(start_time) do
    from(gs in GameSession,
      join: u in User,
      on: gs.user_id == u.id,
      where: gs.game_started_at == ^start_time,
      order_by: [desc: gs.tap_count],
      select: %{
        id: gs.id,
        username: u.username,
        tap_count: gs.tap_count,
        game_ended_at: gs.game_ended_at
      }
    )
    |> Repo.all()
  end
end

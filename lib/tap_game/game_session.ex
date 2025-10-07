defmodule TapGame.GameSession do
  @moduledoc """
  Represents a single game session state.
  Each session can have multiple players and goes through game lifecycle.
  """

  alias TapGame.Games

  @game_duration_seconds 15
  @countdown_seconds 3

  @doc """
  Create a new game session.
  """
  def new(session_id) do
    %{
      id: session_id,
      status: :waiting,  # :waiting, :countdown, :playing, :finished
      players: %{},      # %{user_id => %{username, tap_count}}
      game_start_time: nil,
      game_end_time: nil,
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Add a player to the session.
  """
  def add_player(session, user) do
    players = Map.put(session.players, user.id, %{
      username: user.username,
      tap_count: 0,
      joined_at: DateTime.utc_now()
    })

    %{session | players: players}
  end

  @doc """
  Remove a player from the session.
  """
  def remove_player(session, user_id) do
    players = Map.delete(session.players, user_id)
    %{session | players: players}
  end

  @doc """
  Check if session can start (requires at least 2 players).
  """
  def can_start?(session) do
    session.status == :waiting && map_size(session.players) >= 2
  end

  @doc """
  Start the countdown phase.
  """
  def start_countdown(session) do
    game_start_time = DateTime.add(DateTime.utc_now(), @countdown_seconds, :second)

    %{session |
      status: :countdown,
      game_start_time: game_start_time
    }
  end

  @doc """
  Record a tap for a player (only during playing status).
  """
  def record_tap(session, user_id) do
    if session.status == :playing && Map.has_key?(session.players, user_id) do
      update_in(session.players[user_id].tap_count, &(&1 + 1))
    else
      session
    end
  end

  @doc """
  Handle session lifecycle events.
  """
  def handle_event(session, event) do
    case event do
      :start_countdown ->
        start_countdown(session)

      :start_game ->
        start_game(session)

      :end_game ->
        end_game(session)

      :reset_game ->
        reset_game(session)

      _ ->
        session
    end
  end

  @doc """
  Get public state for broadcasting.
  """
  def get_public_state(session) do
    %{
      session_id: session.id,
      status: session.status,
      players: format_players(session.players),
      game_start_time: session.game_start_time,
      game_end_time: session.game_end_time,
      time_remaining: calculate_time_remaining(session),
      player_count: map_size(session.players)
    }
  end

  # Private Functions

  defp start_game(session) do
    # Only start if we have at least 2 players
    if map_size(session.players) < 2 do
      # Not enough players, reset to waiting
      %{session | status: :waiting, game_start_time: nil}
    else
      game_end_time = DateTime.add(DateTime.utc_now(), @game_duration_seconds, :second)

      # Create game sessions in database for all players
      Enum.each(session.players, fn {user_id, _player_data} ->
        Games.create_game_session(%{
          user_id: user_id,
          game_started_at: session.game_start_time,
          tap_count: 0,
          duration_seconds: @game_duration_seconds
        })
      end)

      %{session |
        status: :playing,
        game_end_time: game_end_time
      }
    end
  end

  defp end_game(session) do
    # Save final scores to database
    Enum.each(session.players, fn {_user_id, player_data} ->
      case Games.get_game_sessions_by_start_time(session.game_start_time) do
        sessions when is_list(sessions) ->
          # Find this player's session
          player_session = Enum.find(sessions, fn s ->
            s.username == player_data.username
          end)

          if player_session && player_session.id do
            case TapGame.Repo.get(TapGame.Games.GameSession, player_session.id) do
              nil -> :ok
              game_session ->
                Games.update_game_session(game_session, %{
                  tap_count: player_data.tap_count,
                  game_ended_at: DateTime.utc_now()
                })
            end
          end
        _ -> :ok
      end
    end)

    %{session | status: :finished}
  end

  defp reset_game(session) do
    # If no players left, mark for cleanup
    if map_size(session.players) == 0 do
      %{session | status: :empty}
    else
      # Reset for new game
      players = Enum.into(session.players, %{}, fn {user_id, player} ->
        {user_id, %{player | tap_count: 0}}
      end)

      %{session |
        status: :waiting,
        players: players,
        game_start_time: nil,
        game_end_time: nil
      }
    end
  end

  defp calculate_time_remaining(session) do
    case session.status do
      :playing ->
        if session.game_end_time do
          DateTime.diff(session.game_end_time, DateTime.utc_now(), :millisecond)
          |> max(0)
          |> div(1000)
        else
          @game_duration_seconds
        end

      :countdown ->
        if session.game_start_time do
          DateTime.diff(session.game_start_time, DateTime.utc_now(), :millisecond)
          |> max(0)
          |> div(1000)
        else
          @countdown_seconds
        end

      _ -> 0
    end
  end

  defp format_players(players) do
    players
    |> Enum.map(fn {user_id, data} ->
      Map.put(data, :user_id, user_id)
    end)
    |> Enum.sort_by(& &1.tap_count, :desc)
  end
end

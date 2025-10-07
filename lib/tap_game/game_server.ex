defmodule TapGame.GameServer do
  @moduledoc """
  GenServer that manages the game state for all connected players.
  Handles game countdown, player registration, and score synchronization.
  """

  use GenServer
  require Logger

  alias TapGame.Games
  alias TapGame.Accounts

  @game_duration_seconds 15
  @countdown_seconds 3

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a player for the next game.
  """
  def register_player(username) do
    GenServer.call(__MODULE__, {:register_player, username})
  end

  @doc """
  Record a tap for a player.
  """
  def record_tap(user_id) do
    GenServer.cast(__MODULE__, {:record_tap, user_id})
  end

  @doc """
  Get the current game state.
  """
  def get_game_state do
    GenServer.call(__MODULE__, :get_game_state)
  end

  @doc """
  Start a new game immediately.
  """
  def start_new_game do
    GenServer.cast(__MODULE__, :start_new_game)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      status: :waiting,  # :waiting, :countdown, :playing, :finished
      players: %{},      # %{user_id => %{username, tap_count, session_id}}
      game_start_time: nil,
      game_end_time: nil,
      countdown_ref: nil,
      game_ref: nil
    }

    Logger.info("GameServer started")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_player, username}, _from, state) do
    case Accounts.get_or_create_user(%{username: username}) do
      {:ok, user} ->
        # If game is waiting, add player and potentially start countdown
        new_state = add_player(state, user)

        # Start countdown if this is the first player and game is waiting
        new_state =
          if map_size(state.players) == 0 and state.status == :waiting do
            schedule_countdown(new_state)
          else
            new_state
          end

        broadcast_state_change(new_state)
        {:reply, {:ok, user}, new_state}

      {:error, changeset} ->
        {:reply, {:error, changeset}, state}
    end
  end

  @impl true
  def handle_call(:get_game_state, _from, state) do
    response = %{
      status: state.status,
      players: format_players(state.players),
      game_start_time: state.game_start_time,
      game_end_time: state.game_end_time,
      time_remaining: calculate_time_remaining(state)
    }
    {:reply, response, state}
  end

  @impl true
  def handle_cast({:record_tap, user_id}, state) do
    # Only record taps when game is playing
    new_state =
      if state.status == :playing and Map.has_key?(state.players, user_id) do
        update_in(state.players[user_id].tap_count, &(&1 + 1))
      else
        state
      end

    if new_state != state do
      broadcast_state_change(new_state)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:start_new_game, state) do
    new_state =
      case state.status do
        :waiting -> schedule_countdown(state)
        :finished -> reset_and_start(state)
        _ -> state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:start_countdown, state) do
    Logger.info("Starting countdown")
    game_start_time = DateTime.add(DateTime.utc_now(), @countdown_seconds, :second)

    new_state = %{state |
      status: :countdown,
      game_start_time: game_start_time,
      countdown_ref: nil
    }

    broadcast_state_change(new_state)

    # Schedule the actual game start
    game_ref = Process.send_after(self(), :start_game, @countdown_seconds * 1000)
    new_state = %{new_state | game_ref: game_ref}

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:start_game, state) do
    Logger.info("Starting game")
    game_end_time = DateTime.add(DateTime.utc_now(), @game_duration_seconds, :second)

    # Create game sessions for all players
    Enum.each(state.players, fn {user_id, _player_data} ->
      Games.create_game_session(%{
        user_id: user_id,
        game_started_at: state.game_start_time,
        tap_count: 0,
        duration_seconds: @game_duration_seconds
      })
    end)

    new_state = %{state |
      status: :playing,
      game_end_time: game_end_time,
      game_ref: nil
    }

    broadcast_state_change(new_state)

    # Schedule game end
    end_ref = Process.send_after(self(), :end_game, @game_duration_seconds * 1000)
    new_state = %{new_state | game_ref: end_ref}

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:end_game, state) do
    Logger.info("Ending game")

    # Save final scores to database
    Enum.each(state.players, fn {_user_id, player_data} ->
      # Find the game session for this user and update it
      case Games.get_game_sessions_by_start_time(state.game_start_time) do
        sessions when is_list(sessions) ->
          session = Enum.find(sessions, fn s -> s.id != nil end)
          if session do
            # Get the full session to update
            case TapGame.Repo.get(TapGame.Games.GameSession, session.id) do
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

    new_state = %{state |
      status: :finished,
      game_ref: nil
    }

    broadcast_state_change(new_state)

    # Schedule reset after showing results
    Process.send_after(self(), :reset_game, 5000)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:reset_game, _state) do
    Logger.info("Resetting game")

    new_state = %{
      status: :waiting,
      players: %{},
      game_start_time: nil,
      game_end_time: nil,
      countdown_ref: nil,
      game_ref: nil
    }

    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  # Private Functions

  defp add_player(state, user) do
    players = Map.put(state.players, user.id, %{
      username: user.username,
      tap_count: 0,
      session_id: user.session_id
    })

    %{state | players: players}
  end

  defp schedule_countdown(state) do
    # Cancel existing countdown if any
    if state.countdown_ref, do: Process.cancel_timer(state.countdown_ref)
    if state.game_ref, do: Process.cancel_timer(state.game_ref)

    # Schedule countdown to start in 5 seconds (waiting for more players)
    countdown_ref = Process.send_after(self(), :start_countdown, 5000)
    %{state | countdown_ref: countdown_ref}
  end

  defp reset_and_start(state) do
    new_state = %{state |
      players: %{},
      game_start_time: nil,
      game_end_time: nil,
      status: :waiting
    }
    schedule_countdown(new_state)
  end

  defp calculate_time_remaining(state) do
    case state.status do
      :playing ->
        if state.game_end_time do
          DateTime.diff(state.game_end_time, DateTime.utc_now(), :millisecond)
          |> max(0)
          |> div(1000)
        else
          @game_duration_seconds
        end

      :countdown ->
        if state.game_start_time do
          DateTime.diff(state.game_start_time, DateTime.utc_now(), :millisecond)
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

  defp broadcast_state_change(state) do
    Phoenix.PubSub.broadcast(
      TapGame.PubSub,
      "game:lobby",
      {:game_state_changed, format_state(state)}
    )
  end

  defp format_state(state) do
    %{
      status: state.status,
      players: format_players(state.players),
      game_start_time: state.game_start_time,
      game_end_time: state.game_end_time,
      time_remaining: calculate_time_remaining(state)
    }
  end
end

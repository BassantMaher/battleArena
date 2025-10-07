defmodule TapGame.SessionManager do
  @moduledoc """
  Manages multiple concurrent game sessions.
  Automatically allocates players to available sessions.
  """

  use GenServer
  require Logger

  alias TapGame.GameSession

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a player and get their session ID.
  """
  def register_player(username) do
    GenServer.call(__MODULE__, {:register_player, username})
  end

  @doc """
  Get the state of a specific session.
  """
  def get_session_state(session_id) do
    GenServer.call(__MODULE__, {:get_session_state, session_id})
  end

  @doc """
  Record a tap for a player in their session (synchronous).
  """
  def record_tap(session_id, user_id) do
    GenServer.call(__MODULE__, {:record_tap, session_id, user_id})
  end

  @doc """
  Record a tap asynchronously for better performance.
  """
  def record_tap_async(session_id, user_id) do
    GenServer.cast(__MODULE__, {:record_tap, session_id, user_id})
  end

  @doc """
  Record multiple taps in a batch for optimal performance.
  """
  def record_taps_batch(session_id, user_id, tap_count) do
    GenServer.cast(__MODULE__, {:record_taps_batch, session_id, user_id, tap_count})
  end

  @doc """
  Manually start a game session.
  """
  def start_session_game(session_id) do
    GenServer.cast(__MODULE__, {:start_session_game, session_id})
  end

  @doc """
  Remove a player from their session (disconnect).
  """
  def remove_player(session_id, user_id) do
    GenServer.cast(__MODULE__, {:remove_player, session_id, user_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      sessions: %{},  # %{session_id => GameSession state}
      user_sessions: %{},  # %{user_id => session_id} for quick lookup
      pending_broadcasts: %{}  # %{session_id => true} for batched broadcasts
    }

    Logger.info("SessionManager started")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_player, username}, _from, state) do
    case TapGame.Accounts.get_or_create_user(%{username: username}) do
      {:ok, user} ->
        # Find or create a suitable session
        {session_id, new_state} = find_or_create_session(state, user)

        # Add player to the session
        new_state = add_player_to_session(new_state, session_id, user)

        # Store user's session mapping
        new_state = put_in(new_state.user_sessions[user.id], session_id)

        # Broadcast to all players in this session
        broadcast_session_state(session_id, new_state.sessions[session_id])

        {:reply, {:ok, user, session_id}, new_state}

      {:error, changeset} ->
        {:reply, {:error, changeset}, state}
    end
  end

  @impl true
  def handle_call({:get_session_state, session_id}, _from, state) do
    session = Map.get(state.sessions, session_id)

    if session do
      response = GameSession.get_public_state(session)
      {:reply, {:ok, response}, state}
    else
      {:reply, {:error, :session_not_found}, state}
    end
  end

  @impl true
  def handle_call({:record_tap, session_id, user_id}, _from, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session do
        GameSession.record_tap(session, user_id)
      else
        nil
      end
    end)

    if new_state.sessions[session_id] do
      broadcast_session_state(session_id, new_state.sessions[session_id])
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:record_tap, session_id, user_id}, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session do
        GameSession.record_tap(session, user_id)
      else
        nil
      end
    end)

    # Schedule a batched broadcast instead of immediate
    schedule_broadcast(session_id)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:record_taps_batch, session_id, user_id, tap_count}, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session do
        GameSession.record_taps_batch(session, user_id, tap_count)
      else
        nil
      end
    end)

    # Schedule a batched broadcast
    schedule_broadcast(session_id)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:broadcast_state, session_id}, state) do
    # Clear any pending broadcast flag
    pending_broadcasts = Map.delete(Map.get(state, :pending_broadcasts, %{}), session_id)
    new_state = Map.put(state, :pending_broadcasts, pending_broadcasts)

    if new_state.sessions[session_id] do
      broadcast_session_state(session_id, new_state.sessions[session_id])
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:start_session_game, session_id}, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session && GameSession.can_start?(session) do
        GameSession.start_countdown(session)
      else
        session
      end
    end)

    if new_state.sessions[session_id] do
      broadcast_session_state(session_id, new_state.sessions[session_id])
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_player, session_id, user_id}, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session do
        GameSession.remove_player(session, user_id)
      else
        nil
      end
    end)

    # Remove user's session mapping
    new_state = update_in(new_state.user_sessions, &Map.delete(&1, user_id))

    # Clean up empty sessions
    new_state = cleanup_empty_session(new_state, session_id)

    if new_state.sessions[session_id] do
      broadcast_session_state(session_id, new_state.sessions[session_id])
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:session_event, session_id, event}, state) do
    new_state = update_in(state.sessions[session_id], fn session ->
      if session do
        GameSession.handle_event(session, event)
      else
        nil
      end
    end)

    if new_state.sessions[session_id] do
      broadcast_session_state(session_id, new_state.sessions[session_id])

      # Schedule next event if needed
      case event do
        :start_countdown ->
          Process.send_after(self(), {:session_event, session_id, :start_game}, 3000)
        :start_game ->
          Process.send_after(self(), {:session_event, session_id, :end_game}, 15000)
        :end_game ->
          Process.send_after(self(), {:session_event, session_id, :reset_game}, 5000)
        _ ->
          :ok
      end
    end

    {:noreply, new_state}
  end

  # Private Functions

  defp find_or_create_session(state, _user) do
    # Find a waiting session with space
    waiting_session = Enum.find(state.sessions, fn {_id, session} ->
      session.status == :waiting && map_size(session.players) < 10
    end)

    case waiting_session do
      {session_id, _session} ->
        {session_id, state}

      nil ->
        # Create new session
        session_id = generate_session_id()
        new_session = GameSession.new(session_id)
        new_state = put_in(state.sessions[session_id], new_session)
        {session_id, new_state}
    end
  end

  defp add_player_to_session(state, session_id, user) do
    update_in(state.sessions[session_id], fn session ->
      new_session = GameSession.add_player(session, user)

      # Auto-start countdown when 2nd player joins
      if map_size(session.players) == 1 && new_session.status == :waiting do
        schedule_session_countdown(session_id)
      end

      new_session
    end)
  end

  defp schedule_session_countdown(session_id) do
    # Wait 5 seconds for more players, then start countdown
    Process.send_after(self(), {:session_event, session_id, :start_countdown}, 5000)
  end

  defp cleanup_empty_session(state, session_id) do
    session = state.sessions[session_id]

    if session && map_size(session.players) == 0 && session.status == :waiting do
      update_in(state.sessions, &Map.delete(&1, session_id))
    else
      state
    end
  end

  defp generate_session_id do
    "session_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp schedule_broadcast(session_id) do
    # Only schedule if not already pending - batches updates every 100ms
    Process.send_after(self(), {:broadcast_state, session_id}, 100)
  end

  defp broadcast_session_state(session_id, session) do
    Phoenix.PubSub.broadcast(
      TapGame.PubSub,
      "game:session:#{session_id}",
      {:session_state_changed, GameSession.get_public_state(session)}
    )
  end
end

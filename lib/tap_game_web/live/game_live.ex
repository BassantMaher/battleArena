defmodule TapGameWeb.GameLive do
  use TapGameWeb, :live_view

  alias TapGame.GameServer
  alias TapGame.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TapGame.PubSub, "game:lobby")
      # Request current game state
      send(self(), :update_game_state)
    end

    {:ok,
     socket
     |> assign(:username, nil)
     |> assign(:user_id, nil)
     |> assign(:registered, false)
     |> assign(:game_state, %{
       status: :waiting,
       players: [],
       time_remaining: 0,
       game_start_time: nil,
       game_end_time: nil
     })
     |> assign(:leaderboard, [])
     |> assign(:username_error, nil)}
  end

  @impl true
  def handle_event("register", %{"username" => username}, socket) do
    username = String.trim(username)

    cond do
      username == "" ->
        {:noreply, assign(socket, :username_error, "Username cannot be empty")}

      String.length(username) < 2 ->
        {:noreply, assign(socket, :username_error, "Username must be at least 2 characters")}

      String.length(username) > 50 ->
        {:noreply, assign(socket, :username_error, "Username must be less than 50 characters")}

      true ->
        case GameServer.register_player(username) do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(:username, user.username)
             |> assign(:user_id, user.id)
             |> assign(:registered, true)
             |> assign(:username_error, nil)
             |> put_flash(:info, "Welcome, #{user.username}!")}

          {:error, _changeset} ->
            {:noreply, assign(socket, :username_error, "Failed to register. Please try again.")}
        end
    end
  end

  @impl true
  def handle_event("tap", _params, socket) do
    if socket.assigns.registered and socket.assigns.game_state.status == :playing do
      GameServer.record_tap(socket.assigns.user_id)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    GameServer.start_new_game()
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_game_state, socket) do
    game_state = GameServer.get_game_state()
    leaderboard = Games.get_leaderboard(10)

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:leaderboard, leaderboard)}
  end

  @impl true
  def handle_info({:game_state_changed, game_state}, socket) do
    leaderboard = 
      if game_state.status == :finished do
        Games.get_leaderboard(10)
      else
        socket.assigns.leaderboard
      end

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:leaderboard, leaderboard)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 p-8">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-5xl font-bold text-white text-center mb-8 drop-shadow-lg">
          ⚡ Tap Battle Arena ⚡
        </h1>

        <%= if !@registered do %>
          <div class="max-w-md mx-auto bg-white/10 backdrop-blur-md rounded-2xl p-8 shadow-2xl">
            <h2 class="text-2xl font-bold text-white mb-4">Join the Game</h2>
            <.form for={%{}} phx-submit="register" class="space-y-4">
              <div>
                <input
                  type="text"
                  name="username"
                  placeholder="Enter your username"
                  class="w-full px-4 py-3 rounded-lg bg-white/20 text-white placeholder-white/60 border-2 border-white/30 focus:border-white/60 focus:outline-none transition"
                  autofocus
                  required
                />
                <%= if @username_error do %>
                  <p class="text-red-300 text-sm mt-2"><%= @username_error %></p>
                <% end %>
              </div>
              <button
                type="submit"
                class="w-full px-6 py-3 bg-gradient-to-r from-pink-500 to-purple-500 text-white font-bold rounded-lg hover:from-pink-600 hover:to-purple-600 transition transform hover:scale-105"
              >
                Join Game
              </button>
            </.form>
          </div>
        <% else %>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Game Area -->
            <div class="lg:col-span-2">
              <div class="bg-white/10 backdrop-blur-md rounded-2xl p-8 shadow-2xl">
                <div class="text-center mb-6">
                  <div class="flex justify-between items-center mb-4">
                    <div class="text-white/80">
                      Playing as: <span class="font-bold text-white"><%= @username %></span>
                    </div>
                    <div class="px-4 py-2 bg-white/20 rounded-full">
                      <span class="text-white font-bold">
                        <%= format_status(@game_state.status) %>
                      </span>
                    </div>
                  </div>

                  <%= cond do %>
                    <% @game_state.status == :waiting -> %>
                      <div class="text-white/80 text-lg mb-4">
                        Waiting for players to join...
                      </div>
                      <div class="text-white/60 text-sm">
                        <%= length(@game_state.players) %> player(s) ready
                      </div>

                    <% @game_state.status == :countdown -> %>
                      <div class="text-8xl font-bold text-white mb-4 animate-pulse">
                        <%= @game_state.time_remaining %>
                      </div>
                      <div class="text-white/80 text-2xl">Get Ready!</div>

                    <% @game_state.status == :playing -> %>
                      <div class="text-6xl font-bold text-white mb-4">
                        <%= @game_state.time_remaining %>s
                      </div>
                      <button
                        phx-click="tap"
                        phx-throttle="50"
                        class="w-full h-64 bg-gradient-to-br from-green-400 to-blue-500 text-white font-bold text-4xl rounded-2xl hover:from-green-500 hover:to-blue-600 transition transform active:scale-95 shadow-2xl"
                      >
                        TAP!
                      </button>
                      <div :if={get_player_taps(@game_state.players, @user_id)} class="mt-4 text-white text-2xl font-bold">
                        Your Taps: <%= get_player_taps(@game_state.players, @user_id) %>
                      </div>

                    <% @game_state.status == :finished -> %>
                      <div class="text-white text-3xl font-bold mb-4">🏆 Game Over! 🏆</div>
                      <%= if length(@game_state.players) > 0 do %>
                        <div class="text-white text-xl mb-4">
                          Winner: <span class="text-yellow-400"><%= hd(@game_state.players).username %></span>
                        </div>
                        <div class="text-white/80 text-lg">
                          with <%= hd(@game_state.players).tap_count %> taps!
                        </div>
                      <% end %>
                  <% end %>
                </div>

                <!-- Current Players -->
                <%= if length(@game_state.players) > 0 do %>
                  <div class="mt-6">
                    <h3 class="text-white font-bold text-lg mb-3">Current Round</h3>
                    <div class="space-y-2">
                      <%= for {player, index} <- Enum.with_index(@game_state.players, 1) do %>
                        <div class="flex items-center justify-between bg-white/10 rounded-lg p-3">
                          <div class="flex items-center space-x-3">
                            <span class="text-2xl">
                              <%= if index == 1, do: "🥇", else: if(index == 2, do: "🥈", else: if(index == 3, do: "🥉", else: "#{index}.")) %>
                            </span>
                            <span class={"font-bold #{if player.user_id == @user_id, do: "text-yellow-400", else: "text-white"}"}>
                              <%= player.username %>
                              <%= if player.user_id == @user_id, do: " (You)" %>
                            </span>
                          </div>
                          <span class="text-white font-bold text-xl"><%= player.tap_count %> taps</span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Leaderboard -->
            <div class="lg:col-span-1">
              <div class="bg-white/10 backdrop-blur-md rounded-2xl p-6 shadow-2xl">
                <h3 class="text-white font-bold text-2xl mb-4">🏆 All-Time Leaderboard</h3>
                <%= if length(@leaderboard) > 0 do %>
                  <div class="space-y-2">
                    <%= for {score, index} <- Enum.with_index(@leaderboard, 1) do %>
                      <div class="flex items-center justify-between bg-white/10 rounded-lg p-3">
                        <div class="flex items-center space-x-2">
                          <span class="text-lg">
                            <%= if index == 1, do: "🥇", else: if(index == 2, do: "🥈", else: if(index == 3, do: "🥉", else: "#{index}.")) %>
                          </span>
                          <span class="text-white font-semibold"><%= score.username %></span>
                        </div>
                        <span class="text-white font-bold"><%= score.tap_count %></span>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-white/60 text-center py-8">
                    No scores yet. Be the first!
                  </div>
                <% end %>
              </div>

              <%= if @game_state.status in [:waiting, :finished] do %>
                <button
                  phx-click="start_game"
                  class="w-full mt-4 px-6 py-3 bg-gradient-to-r from-orange-500 to-red-500 text-white font-bold rounded-lg hover:from-orange-600 hover:to-red-600 transition transform hover:scale-105"
                >
                  <%= if @game_state.status == :waiting, do: "Start Game Now", else: "Play Again" %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_status(:waiting), do: "⏳ Waiting"
  defp format_status(:countdown), do: "🚀 Starting..."
  defp format_status(:playing), do: "🎮 Playing"
  defp format_status(:finished), do: "✅ Finished"

  defp get_player_taps(players, user_id) do
    case Enum.find(players, fn p -> p.user_id == user_id end) do
      nil -> 0
      player -> player.tap_count
    end
  end
end

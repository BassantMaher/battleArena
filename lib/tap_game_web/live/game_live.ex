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
    <div class="min-h-screen bg-gradient-to-br from-pink-50 via-rose-50 to-pink-100 p-4 md:p-8">
      <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <div class="text-center mb-8 md:mb-12">
          <h1 class="text-4xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-r from-pink-600 via-rose-500 to-pink-600 mb-2 animate-gradient">
            ✨ Tap Battle Arena ✨
          </h1>
          <p class="text-pink-600/70 text-sm md:text-base font-medium">Fast fingers win the game!</p>
        </div>

        <%= if !@registered do %>
          <div class="max-w-md mx-auto bg-white rounded-3xl p-8 md:p-10 shadow-xl border border-pink-100">
            <div class="text-center mb-6">
              <div class="w-20 h-20 bg-gradient-to-br from-pink-400 to-rose-400 rounded-full mx-auto mb-4 flex items-center justify-center text-4xl">
                🎮
              </div>
              <h2 class="text-2xl md:text-3xl font-bold text-gray-800 mb-2">Welcome!</h2>
              <p class="text-gray-600 text-sm">Enter your username to join the battle</p>
            </div>
            <.form for={%{}} phx-submit="register" class="space-y-5">
              <div>
                <label class="block text-sm font-semibold text-gray-700 mb-2">Username</label>
                <input
                  type="text"
                  name="username"
                  placeholder="Choose a cool username..."
                  class="w-full px-4 py-3.5 rounded-xl bg-pink-50 text-gray-800 placeholder-gray-400 border-2 border-pink-200 focus:border-pink-400 focus:outline-none focus:ring-2 focus:ring-pink-200 transition"
                  autofocus
                  required
                />
                <%= if @username_error do %>
                  <p class="text-rose-500 text-sm mt-2 flex items-center gap-1">
                    <span>⚠️</span> <%= @username_error %>
                  </p>
                <% end %>
              </div>
              <button
                type="submit"
                class="w-full px-6 py-4 bg-gradient-to-r from-pink-500 to-rose-500 text-white font-bold rounded-xl hover:from-pink-600 hover:to-rose-600 transition transform hover:scale-[1.02] active:scale-[0.98] shadow-lg shadow-pink-300/50"
              >
                🚀 Join Game
              </button>
            </.form>
          </div>
        <% else %>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6">
            <!-- Game Area -->
            <div class="lg:col-span-2 space-y-4 md:space-y-6">
              <!-- Status Card -->
              <div class="bg-white rounded-3xl p-6 md:p-8 shadow-lg border border-pink-100">
                <div class="flex flex-col md:flex-row justify-between items-center gap-4 mb-6">
                  <div class="text-center md:text-left">
                    <p class="text-gray-500 text-sm mb-1">Playing as</p>
                    <p class="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-pink-600 to-rose-600">
                      <%= @username %>
                    </p>
                  </div>
                  <div class="px-6 py-3 bg-gradient-to-r from-pink-100 to-rose-100 rounded-full">
                    <span class="font-bold text-pink-700">
                      <%= format_status(@game_state.status) %>
                    </span>
                  </div>
                </div>

                <div class="text-center">
                  <%= cond do %>
                    <% @game_state.status == :waiting -> %>
                      <div class="py-12">
                        <div class="w-24 h-24 bg-gradient-to-br from-pink-200 to-rose-200 rounded-full mx-auto mb-6 flex items-center justify-center animate-pulse">
                          <span class="text-4xl">⏳</span>
                        </div>
                        <p class="text-gray-600 text-lg md:text-xl mb-2 font-medium">
                          Waiting for players to join...
                        </p>
                        <p class="text-gray-500 text-sm">
                          <%= length(@game_state.players) %> player(s) ready
                        </p>
                      </div>

                    <% @game_state.status == :countdown -> %>
                      <div class="py-12">
                        <div class="text-8xl md:text-9xl font-black text-transparent bg-clip-text bg-gradient-to-br from-pink-500 via-rose-500 to-pink-600 mb-6 animate-pulse">
                          <%= @game_state.time_remaining %>
                        </div>
                        <p class="text-gray-700 text-2xl md:text-3xl font-bold">Get Ready! 🚀</p>
                      </div>

                    <% @game_state.status == :playing -> %>
                      <div class="mb-6">
                        <div class="inline-block px-8 py-4 bg-gradient-to-r from-pink-100 to-rose-100 rounded-2xl mb-6">
                          <span class="text-5xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-r from-pink-600 to-rose-600">
                            <%= @game_state.time_remaining %>
                          </span>
                          <span class="text-2xl md:text-3xl text-pink-600 font-bold ml-2">sec</span>
                        </div>
                      </div>
                      <button
                        phx-click="tap"
                        phx-throttle="50"
                        class="w-full h-56 md:h-64 bg-gradient-to-br from-pink-400 via-rose-400 to-pink-500 text-white font-black text-4xl md:text-5xl rounded-3xl hover:from-pink-500 hover:via-rose-500 hover:to-pink-600 transition-all transform hover:scale-[1.02] active:scale-95 shadow-2xl shadow-pink-300/50 relative overflow-hidden group"
                      >
                        <span class="relative z-10">TAP ME! 👆</span>
                        <div class="absolute inset-0 bg-gradient-to-t from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
                      </button>
                      <div :if={get_player_taps(@game_state.players, @user_id)} class="mt-6 inline-block px-6 py-3 bg-pink-100 rounded-2xl">
                        <span class="text-gray-600 text-sm font-semibold">Your Taps: </span>
                        <span class="text-pink-600 text-3xl font-black ml-2">
                          <%= get_player_taps(@game_state.players, @user_id) %>
                        </span>
                      </div>

                    <% @game_state.status == :finished -> %>
                      <div class="py-8">
                        <div class="text-6xl mb-4">🏆</div>
                        <h3 class="text-3xl md:text-4xl font-black text-gray-800 mb-6">Game Over!</h3>
                        <%= if length(@game_state.players) > 0 do %>
                          <div class="bg-gradient-to-r from-yellow-50 to-amber-50 border-2 border-yellow-200 rounded-2xl p-6 mb-4">
                            <p class="text-gray-600 text-sm mb-2">👑 Winner</p>
                            <p class="text-3xl font-black text-transparent bg-clip-text bg-gradient-to-r from-yellow-600 to-amber-600">
                              <%= hd(@game_state.players).username %>
                            </p>
                            <p class="text-gray-700 text-lg mt-3">
                              with <span class="font-bold text-pink-600"><%= hd(@game_state.players).tap_count %></span> taps!
                            </p>
                          </div>
                        <% end %>
                      </div>
                  <% end %>
                </div>
              </div>

              <!-- Current Players -->
              <%= if length(@game_state.players) > 0 do %>
                <div class="bg-white rounded-3xl p-6 md:p-8 shadow-lg border border-pink-100">
                  <h3 class="text-xl font-bold text-gray-800 mb-4 flex items-center gap-2">
                    <span>🎯</span> Current Round
                  </h3>
                  <div class="space-y-3">
                    <%= for {player, index} <- Enum.with_index(@game_state.players, 1) do %>
                      <div class={"flex items-center justify-between rounded-2xl p-4 transition #{if player.user_id == @user_id, do: "bg-gradient-to-r from-pink-100 to-rose-100 border-2 border-pink-300", else: "bg-gray-50 hover:bg-gray-100"}"}>
                        <div class="flex items-center space-x-3">
                          <span class="text-2xl w-8">
                            <%= if index == 1, do: "🥇", else: if(index == 2, do: "🥈", else: if(index == 3, do: "🥉", else: "#{index}")) %>
                          </span>
                          <div>
                            <p class={"font-bold text-lg #{if player.user_id == @user_id, do: "text-pink-700", else: "text-gray-800"}"}>
                              <%= player.username %>
                            </p>
                            <%= if player.user_id == @user_id do %>
                              <p class="text-pink-600 text-xs font-semibold">You</p>
                            <% end %>
                          </div>
                        </div>
                        <div class="text-right">
                          <p class="text-2xl font-black text-gray-800"><%= player.tap_count %></p>
                          <p class="text-xs text-gray-500">taps</p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Leaderboard -->
            <div class="lg:col-span-1 space-y-4">
              <div class="bg-white rounded-3xl p-6 shadow-lg border border-pink-100 sticky top-4">
                <div class="flex items-center gap-2 mb-5">
                  <span class="text-2xl">🏆</span>
                  <h3 class="text-xl font-bold text-gray-800">All-Time Leaders</h3>
                </div>
                <%= if length(@leaderboard) > 0 do %>
                  <div class="space-y-2.5">
                    <%= for {score, index} <- Enum.with_index(@leaderboard, 1) do %>
                      <div class={"flex items-center justify-between rounded-xl p-3 transition #{if index <= 3, do: "bg-gradient-to-r from-yellow-50 to-amber-50 border border-yellow-200", else: "bg-gray-50 hover:bg-gray-100"}"}>
                        <div class="flex items-center space-x-3">
                          <span class={"text-xl font-bold #{if index <= 3, do: "w-6", else: "w-6 text-gray-400"}"}>
                            <%= if index == 1, do: "🥇", else: if(index == 2, do: "🥈", else: if(index == 3, do: "🥉", else: "#{index}")) %>
                          </span>
                          <div>
                            <p class={"font-bold text-sm #{if index <= 3, do: "text-gray-800", else: "text-gray-600"}"}>
                              <%= score.username %>
                            </p>
                          </div>
                        </div>
                        <div class="text-right">
                          <p class={"font-black #{if index == 1, do: "text-xl text-yellow-600", else: "text-lg text-gray-700"}"}>
                            <%= score.tap_count %>
                          </p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center py-12">
                    <div class="w-16 h-16 bg-pink-100 rounded-full mx-auto mb-4 flex items-center justify-center">
                      <span class="text-3xl">🎯</span>
                    </div>
                    <p class="text-gray-500 text-sm">No scores yet.</p>
                    <p class="text-pink-600 text-sm font-semibold mt-1">Be the first champion!</p>
                  </div>
                <% end %>
              </div>

              <%= if @game_state.status in [:waiting, :finished] do %>
                <button
                  phx-click="start_game"
                  class="w-full px-6 py-4 bg-gradient-to-r from-pink-500 to-rose-500 text-white font-bold rounded-2xl hover:from-pink-600 hover:to-rose-600 transition-all transform hover:scale-[1.02] active:scale-[0.98] shadow-lg shadow-pink-300/50"
                >
                  <%= if @game_state.status == :waiting do %>
                    ⚡ Start Game Now
                  <% else %>
                    🔄 Play Again
                  <% end %>
                </button>
              <% end %>

              <!-- Info Card -->
              <div class="bg-gradient-to-br from-pink-50 to-rose-50 rounded-2xl p-5 border border-pink-100">
                <h4 class="font-bold text-gray-800 text-sm mb-3 flex items-center gap-2">
                  <span>💡</span> How to Play
                </h4>
                <ul class="space-y-2 text-xs text-gray-600">
                  <li class="flex items-start gap-2">
                    <span class="text-pink-500 mt-0.5">•</span>
                    <span>Tap the button as fast as you can</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <span class="text-pink-500 mt-0.5">•</span>
                    <span>You have 15 seconds to tap</span>
                  </li>
                  <li class="flex items-start gap-2">
                    <span class="text-pink-500 mt-0.5">•</span>
                    <span>Player with most taps wins!</span>
                  </li>
                </ul>
              </div>
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

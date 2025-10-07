# Tap Battle Arena 🎮⚡

A real-time multi-player tap game built with Elixir, Phoenix LiveView, and PostgreSQL. Players compete in 15-second sprints to see who can tap the fastest!

## Features

✅ **Real-time Multiplayer** - Multiple players can join and compete simultaneously  
✅ **Time Synchronization** - Uses UTC timestamps to ensure fairness across timezones  
✅ **Live Updates** - Phoenix PubSub broadcasts game state to all connected players  
✅ **Leaderboard** - Persistent all-time high scores stored in PostgreSQL  
✅ **Countdown Timer** - 3-second countdown before each game starts  
✅ **User Management** - Unique usernames with database persistence  
✅ **Responsive UI** - Beautiful gradient design with Tailwind CSS

## How It Works

### Time Synchronization & Fairness

The game ensures fairness for players in different geographic locations by:

1. **UTC Timestamps**: All game events use `DateTime.utc_now()` to eliminate timezone confusion
2. **Server-Side Game State**: The `GameServer` GenServer manages the authoritative game state
3. **Synchronized Start**: All players receive the exact same start time via Phoenix PubSub
4. **Client-Side Display**: Each client displays the countdown and timer in their local time
5. **Server-Side Validation**: All taps are recorded on the server, preventing client-side manipulation

### Architecture

```
┌─────────────────┐
│  GameServer     │  ← Single source of truth for game state
│  (GenServer)    │  ← Manages countdown, game timer, scores
└────────┬────────┘
         │
         ├──── Phoenix.PubSub ────┐
         │                        │
    ┌────▼────┐              ┌────▼────┐
    │ Player  │              │ Player  │
    │ Browser │              │ Browser │
    │(LiveView)│             │(LiveView)│
    └─────────┘              └─────────┘
```

## Prerequisites

- Elixir 1.14+ and OTP 25+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

## Installation & Setup

### 1. Clone or Navigate to the Project

```bash
cd d:\bassant\Freelancing\task3\tap_game
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies for assets
cd assets && npm install && cd ..
```

### 3. Configure Database

Edit `config/dev.exs` to match your PostgreSQL credentials:

```elixir
config :tap_game, TapGame.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tap_game_dev"
```

### 4. Create and Migrate Database

```bash
# Create the database
mix ecto.create

# Run migrations
mix ecto.migrate
```

### 5. Start the Server

```bash
# Start Phoenix server
mix phx.server
```

The application will be available at [http://localhost:4000](http://localhost:4000)

## Usage

### Playing the Game

1. **Join**: Open the browser and enter a unique username
2. **Wait**: The game starts automatically when players join (5-second wait)
3. **Countdown**: A 3-second countdown prepares players
4. **Tap**: Click/tap the button as many times as possible in 15 seconds
5. **Results**: See your ranking and the winner
6. **Play Again**: Start a new round

### Multiple Players

To test with multiple players:

1. Open multiple browser windows/tabs
2. Use different usernames in each
3. All players will see synchronized countdown and timer
4. Scores update in real-time for all players

## Database Schema

### Users Table

```elixir
create table(:users) do
  add :id, :binary_id, primary_key: true
  add :username, :string, null: false
  add :session_id, :string
  timestamps(type: :utc_datetime)
end
```

### Game Sessions Table

```elixir
create table(:game_sessions) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id)
  add :tap_count, :integer, default: 0
  add :game_started_at, :utc_datetime, null: false
  add :game_ended_at, :utc_datetime
  add :duration_seconds, :integer, default: 15
  timestamps(type: :utc_datetime)
end
```

## Key Components

### GameServer (GenServer)

Located at: `lib/tap_game/game_server.ex`

- Manages global game state (waiting, countdown, playing, finished)
- Handles player registration
- Coordinates countdown and game timers
- Broadcasts state changes via PubSub
- Saves scores to database

### GameLive (LiveView)

Located at: `lib/tap_game_web/live/game_live.ex`

- Real-time UI for the game
- Handles user registration
- Records taps and sends to GameServer
- Displays live leaderboard
- Responsive design with Tailwind CSS

### Contexts

- `TapGame.Accounts` - User management
- `TapGame.Games` - Game session and score management

## Configuration

### Game Duration

To change the game duration, edit `lib/tap_game/game_server.ex`:

```elixir
@game_duration_seconds 15  # Change this value
```

### Countdown Duration

```elixir
@countdown_seconds 3  # Change this value
```

## Production Deployment

### 1. Set Production Database

Edit `config/runtime.exs` with your production database URL.

### 2. Set Secret Key Base

```bash
mix phx.gen.secret
```

Add the generated key to your environment variables.

### 3. Build Assets

```bash
mix assets.deploy
```

### 4. Run Migrations

```bash
MIX_ENV=prod mix ecto.migrate
```

### 5. Start Server

```bash
MIX_ENV=prod mix phx.server
```

## Testing

### Run Tests

```bash
mix test
```

### Test Multiple Players Locally

1. Open multiple browser windows
2. Navigate to `http://localhost:4000` in each
3. Use different usernames
4. Verify synchronized gameplay

## Troubleshooting

### Database Connection Error

- Ensure PostgreSQL is running
- Check credentials in `config/dev.exs`
- Create database: `mix ecto.create`

### Port Already in Use

Change the port in `config/dev.exs`:

```elixir
http: [ip: {127, 0, 0, 1}, port: 4001]
```

### Assets Not Loading

```bash
cd assets
npm install
cd ..
mix phx.server
```

## Technical Highlights

### Time Synchronization

The game uses UTC timestamps throughout to ensure fairness:

```elixir
# Server-side: Calculate synchronized start time
game_start_time = DateTime.add(DateTime.utc_now(), @countdown_seconds, :second)

# All clients receive the same start time via PubSub
Phoenix.PubSub.broadcast(TapGame.PubSub, "game:lobby", {:game_state_changed, state})
```

### Real-time Updates

Phoenix PubSub ensures all players see the same game state:

```elixir
# Server broadcasts changes
Phoenix.PubSub.broadcast(TapGame.PubSub, "game:lobby", {:game_state_changed, game_state})

# LiveView receives updates
def handle_info({:game_state_changed, game_state}, socket) do
  {:noreply, assign(socket, :game_state, game_state)}
end
```

### Fair Tap Recording

All taps are validated server-side:

```elixir
def handle_cast({:record_tap, user_id}, state) do
  # Only record if game is actively playing
  if state.status == :playing and Map.has_key?(state.players, user_id) do
    update_in(state.players[user_id].tap_count, &(&1 + 1))
  end
end
```

## License

MIT License

## Author

Built with ❤️ using Elixir and Phoenix LiveView

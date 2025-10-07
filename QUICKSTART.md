# Quick Start Guide - Tap Battle Arena

## Prerequisites Check

Before starting, ensure you have:
- ✅ Elixir installed (`elixir --version`)
- ✅ PostgreSQL running
- ✅ Node.js installed (`node --version`)

## Option 1: Automated Setup (Windows)

```cmd
setup.bat
```

Then start the server:
```cmd
mix phx.server
```

## Option 2: Manual Setup

### Step 1: Install Dependencies

```cmd
mix deps.get
cd assets && npm install && cd ..
```

### Step 2: Configure Database

Edit `config/dev.exs` if your PostgreSQL credentials differ:

```elixir
config :tap_game, TapGame.Repo,
  username: "postgres",      # Your PostgreSQL username
  password: "postgres",      # Your PostgreSQL password
  hostname: "localhost",
  database: "tap_game_dev"
```

### Step 3: Setup Database

```cmd
mix ecto.create
mix ecto.migrate
```

### Step 4: Start Server

```cmd
mix phx.server
```

## Access the Game

Open your browser to: **http://localhost:4000**

## Test Multi-Player

1. Open multiple browser windows/tabs
2. Go to `http://localhost:4000` in each
3. Enter different usernames
4. Watch the synchronized countdown and play together!

## Common Issues

### "Database does not exist"
```cmd
mix ecto.create
```

### "Connection refused" (PostgreSQL)
- Start PostgreSQL service
- Check credentials in `config/dev.exs`

### Port 4000 already in use
- Kill the process or change port in `config/dev.exs`

## Features to Try

- ✅ Register with a unique username
- ✅ Wait for the countdown (3 seconds)
- ✅ Tap as fast as you can for 15 seconds
- ✅ Check the all-time leaderboard
- ✅ Play again and beat your high score!

## Need Help?

Check the full documentation in `GAME_README.md`

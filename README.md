# 🎮 Tap Battle Arena

> A real-time multiplayer tapping game built with Phoenix LiveView and Elixir

[![Elixir](https://img.shields.io/badge/Elixir-1.18.4-purple.svg)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8.1-orange.svg)](https://phoenixframework.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-blue.svg)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🎥 Demo Video

**[▶️ Watch the Demo](https://drive.google.com/file/d/1xwJppATsD2ORRGh3gBbRIc7zW-Z_Mjq6/view?usp=sharing)**

See Tap Battle Arena in action! This demo showcases real-time multiplayer gameplay, instant tap counting, and the complete game flow from registration to winner announcement.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [How to Play](#how-to-play)
- [Architecture](#architecture)
  - [Database Schema](#database-schema)
  - [Session Management](#session-management)
  - [Game Logic & State Machine](#game-logic--state-machine)
  - [Real-Time Communication](#real-time-communication)
- [Session Allocation System](#session-allocation-system)
- [Game Timing & Mechanics](#game-timing--mechanics)
- [Performance Optimizations](#performance-optimizations)
- [Testing Guide](#testing-guide)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Tap Battle Arena** is a high-performance, real-time multiplayer game where players compete to achieve the highest number of taps within a 15-second sprint. Built on Phoenix LiveView, the game leverages WebSocket connections for instant updates and features an optimized client-side tap counting system for zero-latency feedback.

### Key Highlights

- **Real-time multiplayer**: Compete with players worldwide
- **Zero-lag tapping**: Client-side optimization with 200ms sync intervals
- **Fair gameplay**: UTC timestamps ensure timezone-agnostic fairness
- **Automatic session management**: Players are automatically allocated to available games
- **Persistent leaderboards**: PostgreSQL database tracks all-time champions

---

## ✨ Features

### Core Gameplay
- ⚡ **Fast-paced tapping**: 15-second competitive rounds
- 🎹 **Dual input methods**: Mouse clicks OR spacebar tapping
- 🏆 **Live leaderboards**: Real-time rankings and all-time champions
- 👥 **Multiplayer sessions**: Up to 10 players per game
- 🌍 **Timezone-fair**: UTC timestamps ensure equal start times globally

### Technical Features
- 🚀 **Instant feedback**: Client-side tap counting (0ms perceived latency)
- 📊 **Batch synchronization**: Optimized network traffic with 200ms updates
- 🔄 **Automatic session allocation**: Smart matchmaking system
- 💾 **Persistent storage**: PostgreSQL database for users and game sessions
- 🎨 **Modern UI**: Beautiful gradient animations with Tailwind CSS
- 📱 **Responsive design**: Works on desktop, tablet, and mobile

---

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

- **Elixir**: 1.18.4 or higher
- **Erlang/OTP**: 25 or higher
- **Phoenix Framework**: 1.8.1 or higher
- **PostgreSQL**: 14.0 or higher
- **Node.js**: 18.0 or higher (for asset compilation)
- **Git**: For version control

### Verify Installation

```bash
# Check Elixir version
elixir --version

# Check Erlang version
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

# Check PostgreSQL
psql --version

# Check Node.js
node --version
```

---

## 🚀 Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/BassantMaher/battleArena.git
cd tap_game
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies for assets
cd assets && npm install && cd ..

# Compile dependencies
mix deps.compile
```

### 3. Configure Database

Edit `config/dev.exs` to match your PostgreSQL credentials:

```elixir
config :tap_game, TapGame.Repo,
  username: "postgres",
  password: "your_password",
  hostname: "localhost",
  database: "tap_game_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
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

# Or start with interactive Elixir shell
iex -S mix phx.server
```

The application will be available at **http://localhost:3000**

---

## 🎮 How to Play

### Getting Started

1. **Open the game** in your browser: `http://localhost:3000`
2. **Enter your username** (2-50 characters)
3. **Wait for another player** to join (minimum 2 players required)
4. **Click "Start Game"** when ready

### During the Game

#### Countdown Phase (3 seconds)
- A countdown timer appears
- Get your fingers ready!
- Countdown: 3... 2... 1...

#### Playing Phase (15 seconds)
- **Tap the button** as fast as you can!
- **Alternative**: Press the **SPACEBAR** for rapid tapping
- Watch your tap count increase instantly
- See real-time rankings update

#### Results Phase
- 🏆 Winner is announced
- Final scores are displayed
- All-time leaderboard updates
- Option to **Play Again**

### Pro Tips

- 💡 **Use spacebar**: Generally faster than mouse clicking
- 💡 **Steady rhythm**: Consistent tapping beats frantic mashing
- 💡 **Watch the timer**: Pace yourself for the full 15 seconds
- 💡 **Stay focused**: Every tap counts!

---

## 🏗️ Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Browser                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Phoenix LiveView (GameLive)                 │   │
│  │  • Client-side JS Hook (TapHandler)                  │   │
│  │  • Instant local tap counting                        │   │
│  │  • 200ms batch sync to server                        │   │
│  └─────────────────┬────────────────────────────────────┘   │
└────────────────────┼──────────────────────────────────────────┘
                     │ WebSocket (Phoenix Channel)
                     │
┌────────────────────┼──────────────────────────────────────────┐
│                    ▼            Phoenix Server                │
│  ┌─────────────────────────────────────────────────────┐     │
│  │            SessionManager (GenServer)                │     │
│  │  • Manages multiple concurrent game sessions        │     │
│  │  • Auto-allocates players to sessions               │     │
│  │  • Batched state broadcasts (100ms)                 │     │
│  └──────────────────┬──────────────────────────────────┘     │
│                     │                                          │
│  ┌──────────────────▼──────────────────────────────────┐     │
│  │         GameSession (State Module)                   │     │
│  │  • Individual session state & lifecycle             │     │
│  │  • Player management & tap counting                 │     │
│  │  • Game timing & state transitions                  │     │
│  └──────────────────┬──────────────────────────────────┘     │
│                     │                                          │
│  ┌──────────────────▼──────────────────────────────────┐     │
│  │         PostgreSQL Database (Ecto)                   │     │
│  │  • Users table                                       │     │
│  │  • Game sessions table                              │     │
│  │  • Persistent leaderboards                          │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

---

## 💾 Database Schema

### Tables Overview

#### 1. **Users Table** (`users`)

Stores player information and associates them with game sessions.

```sql
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  session_id VARCHAR(255),
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX users_username_index ON users(username);
CREATE INDEX users_session_id_index ON users(session_id);
```

**Fields:**
- `id`: Unique identifier (auto-increment)
- `username`: Player's chosen username (unique, 2-50 characters)
- `session_id`: Current or last session ID (nullable)
- `inserted_at`: Account creation timestamp (UTC)
- `updated_at`: Last activity timestamp (UTC)

#### 2. **Game Sessions Table** (`game_sessions`)

Records every game played with final scores and timing information.

```sql
CREATE TABLE game_sessions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  tap_count INTEGER DEFAULT 0,
  duration_seconds INTEGER DEFAULT 15,
  game_started_at TIMESTAMP,
  game_ended_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX game_sessions_user_id_index ON game_sessions(user_id);
CREATE INDEX game_sessions_tap_count_index ON game_sessions(tap_count DESC);
CREATE INDEX game_sessions_game_started_at_index ON game_sessions(game_started_at);
```

**Fields:**
- `id`: Unique game record identifier
- `user_id`: Foreign key to users table
- `tap_count`: Final number of taps achieved
- `duration_seconds`: Game duration (always 15)
- `game_started_at`: Exact UTC timestamp when game began
- `game_ended_at`: Exact UTC timestamp when game finished
- `inserted_at`: Database insertion time (UTC)
- `updated_at`: Last update time (UTC)

### Database Queries

#### Get Top 10 Leaderboard

```elixir
def get_leaderboard(limit \\ 10) do
  from(g in GameSession,
    join: u in User,
    on: g.user_id == u.id,
    where: not is_nil(g.game_ended_at),
    order_by: [desc: g.tap_count],
    limit: ^limit,
    select: %{
      username: u.username,
      tap_count: g.tap_count,
      game_date: g.game_started_at
    }
  )
  |> Repo.all()
end
```

---

## 🎯 Session Management

### Session Lifecycle

```
┌─────────────┐
│   WAITING   │ ◄─── Initial state when session is created
└──────┬──────┘
       │ 2nd player joins → Auto-start countdown in 5s
       │
┌──────▼──────┐
│  COUNTDOWN  │ ◄─── 3-second countdown (3... 2... 1...)
└──────┬──────┘
       │ Countdown complete
       │
┌──────▼──────┐
│   PLAYING   │ ◄─── 15-second active game
└──────┬──────┘
       │ Time expires
       │
┌──────▼──────┐
│  FINISHED   │ ◄─── Show results, save scores
└──────┬──────┘
       │ After 5s OR "Play Again" clicked
       │
┌──────▼──────┐
│   WAITING   │ ◄─── Reset and ready for next game
└─────────────┘
```

### Session Creation & Allocation

#### Automatic Session Allocation Algorithm

```elixir
def find_or_create_session(state, user) do
  # Step 1: Try to find an existing waiting session with space
  waiting_session = Enum.find(state.sessions, fn {_id, session} ->
    session.status == :waiting && map_size(session.players) < 10
  end)
  
  case waiting_session do
    # Found existing session - join it
    {session_id, _session} ->
      {session_id, state}
    
    # No available session - create new one
    nil ->
      session_id = generate_session_id()
      new_session = GameSession.new(session_id)
      new_state = put_in(state.sessions[session_id], new_session)
      {session_id, new_state}
  end
end
```

#### Session ID Generation

Session IDs are cryptographically secure random strings:

```elixir
def generate_session_id do
  "session_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
end

# Example output: "session_a3f7b2e8c9d1f4a6"
```

---

## ⚙️ Game Logic & State Machine

### Game Rules

##### 1. **Minimum Players Rule**

```elixir
def can_start?(session) do
  session.status == :waiting && map_size(session.players) >= 2
end

# Games require at least 2 players to start
# Prevents single-player exploitation
```

##### 2. **Tap Validation**

```elixir
def record_taps_batch(session, user_id, tap_count) do
  if session.status == :playing && 
     Map.has_key?(session.players, user_id) && 
     tap_count > 0 do
    # Valid tap - record it
    update_in(session.players[user_id].tap_count, &(&1 + tap_count))
  else
    # Invalid tap - ignore it
    session
  end
end

# Taps only count during :playing status
# User must be in the session
# Tap count must be positive
```

---

## 🔄 Session Allocation System

### Smart Matchmaking

The system automatically allocates players to sessions using an intelligent algorithm:

#### Allocation Strategy

```
┌──────────────────────────────────────────────────────────┐
│              Player Joins Game                            │
└──────────────────┬───────────────────────────────────────┘
                   │
       ┌───────────▼───────────┐
       │ Search for Available  │
       │   Waiting Session     │
       │  (< 10 players)       │
       └───────────┬───────────┘
                   │
            ┌──────┴──────┐
            │             │
       ┌────▼────┐   ┌────▼────┐
       │ Found?  │   │ Not     │
       │  YES    │   │ Found?  │
       └────┬────┘   └────┬────┘
            │             │
     ┌──────▼──────┐      │
     │ Join        │      │
     │ Existing    │      │
     │ Session     │      │
     └─────────────┘      │
                    ┌─────▼─────┐
                    │ Create    │
                    │ New       │
                    │ Session   │
                    └───────────┘
```

---

## ⏱️ Game Timing & Mechanics

### Timeline of a Complete Game

```
T=0s    Player 1 joins
        └─► Session created, status: :waiting

T=2s    Player 2 joins
        └─► Auto-start countdown scheduled for T=7s

T=7s    Countdown begins, status: :countdown
        └─► Display: "3..."

T=8s    Display: "2..."

T=9s    Display: "1..."

T=10s   Game starts, status: :playing
        ├─► game_start_time = UTC now
        ├─► game_end_time = UTC now + 15s
        └─► Database records created

T=10-25s Players tap frantically
        ├─► Client-side instant counting
        ├─► Batch updates every 200ms to server
        └─► Server broadcasts every 100ms to all players

T=25s   Game ends, status: :finished
        ├─► Final scores saved to database
        ├─► Winner announced
        └─► Leaderboard updated

T=30s   Reset delay complete
        └─► If players remain: status: :waiting (ready for next round)
            If no players: session deleted
```

### UTC Timestamp Usage

All game timing uses UTC timestamps to ensure fairness across timezones:

```elixir
# Game start
game_start_time = DateTime.utc_now()
game_end_time = DateTime.add(game_start_time, 15, :second)

# Time remaining calculation
remaining_ms = DateTime.diff(game_end_time, DateTime.utc_now(), :millisecond)
remaining_seconds = max(0, div(remaining_ms, 1000))
```

**Why UTC?**
- Player in New York: Local 3:00 PM → UTC 8:00 PM
- Player in Tokyo: Local 5:00 AM → UTC 8:00 PM
- Both players see countdown start at **exactly the same moment**

---

## 🚀 Performance Optimizations

### Client-Side Tap Counting

#### Performance Comparison

| Method | Latency | Max Taps/Sec | Network Calls |
|--------|---------|--------------|---------------|
| **Original** | 50-100ms | ~10-20 | 1 per tap |
| **Optimized** | **0ms** | **Unlimited** | **5 per second** |

### JavaScript Hook Implementation

```javascript
Hooks.TapHandler = {
  mounted() {
    this.tapCount = 0
    this.lastSent = 0
    
    this.el.addEventListener("click", () => {
      this.tapCount++
      this.updateDisplay()  // Instant! 0ms
      this.sendUpdate()     // Async batch update
    })
    
    // Batch sync every 200ms
    setInterval(() => {
      if (this.tapCount > this.lastSent) {
        this.pushEvent("tap_update", { count: this.tapCount })
        this.lastSent = this.tapCount
      }
    }, 200)
  }
}
```

### Benefits

- **95% reduction** in network traffic
- **Smooth updates** for all players
- **Scalable** to hundreds of concurrent players
- **Battery efficient** for mobile devices

---

## 🧪 Testing Guide

### Manual Testing

#### 1. **Single Player Test**

```bash
# Start server
mix phx.server

# Open browser: http://localhost:3000
# Enter username: "TestPlayer1"
# Expected: "Need 1 more player..." displayed
```

#### 2. **Two Player Test**

```bash
# Open TWO browser tabs or windows
# Tab 1: Username "Player1"
# Tab 2: Username "Player2"
# Expected: Auto-countdown starts 5s after Player2 joins
# Expected: Game starts after 3-second countdown
# Both players can tap simultaneously
```

#### 3. **Keyboard Tapping Test**

```bash
# During game (status: playing)
# Press SPACEBAR rapidly
# Expected: Tap count increases instantly
# Expected: No missed taps
# Expected: Count updates smoothly
```

#### 4. **Multiple Sessions Test**

```bash
# Open 4 browser tabs
# Tab 1 & 2: Session 1 (Player1, Player2)
# Tab 3 & 4: Session 2 (Player3, Player4)
# Expected: Two separate games running concurrently
# Expected: No cross-session interference
```

### Automated Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover
```

---

## ⚙️ Configuration

### Customization Options

```elixir
# lib/tap_game/game_session.ex

# Adjust game duration
@game_duration_seconds 15  # Change to 30, 60, etc.

# Adjust countdown time
@countdown_seconds 3  # Change to 5, 10, etc.

# lib/tap_game/session_manager.ex

# Max players per session
@max_players_per_session 10  # Increase for larger games
```

---

## 🐛 Troubleshooting

### Common Issues

#### Database Connection Error

```bash
# Check PostgreSQL is running
sudo service postgresql status

# Create database if not exists
mix ecto.create
```

#### Port Already in Use

```bash
# Find and kill process using port 3000
lsof -ti:3000 | xargs kill -9

# Or use different port
PORT=4001 mix phx.server
```

#### Assets Not Compiling

```bash
# Install Node dependencies
cd assets && npm install && cd ..

# Rebuild assets
mix assets.build
```

---

<div align="center">


[Report Bug](https://github.com/BassantMaher/battleArena/issues) · [Request Feature](https://github.com/BassantMaher/battleArena/issues)

</div> 

# Session Management System 🎮

## Overview

The Tap Battle Arena now uses an **automatic session allocation system** that manages multiple concurrent game sessions. Players are automatically assigned to available sessions, ensuring fair gameplay and preventing games from starting without players.

## Key Features

### ✅ Automatic Session Allocation
- Players are automatically assigned to available sessions when they join
- Sessions are created on-demand as players register
- Maximum 10 players per session
- Players in different sessions don't interfere with each other

### ✅ Session Lifecycle Management
- **Waiting**: Session is open for players to join
- **Countdown**: 3-second countdown before game starts (only with players)
- **Playing**: Active 15-second game in progress
- **Finished**: Game completed, showing results
- **Empty**: Session automatically cleaned up when all players leave

### ✅ Player Management
- Real-time player tracking per session
- Automatic removal when players disconnect
- Session cleanup when empty
- Player count displayed to all participants

### ✅ Fair Game Start
- Games **ONLY** start if there are active players in the session
- If all players disconnect during countdown, the game resets to waiting
- Automatic countdown begins 5 seconds after first player joins
- Manual start button available (only when players are present)

## Architecture

```
┌──────────────────────────────────────┐
│      SessionManager (GenServer)       │
│  - Manages multiple game sessions     │
│  - Auto-allocates players to sessions │
│  - Tracks user→session mapping        │
└────────────┬─────────────────────────┘
             │
             ├─── Manages ───┐
             │                │
    ┌────────▼──────┐  ┌─────▼─────────┐
    │  GameSession  │  │  GameSession  │
    │    (State)    │  │    (State)    │
    │  Session #1   │  │  Session #2   │
    │  Players: 3   │  │  Players: 2   │
    └───────────────┘  └───────────────┘
             │                │
             └────── PubSub ──┘
                     │
         ┌───────────┼───────────┐
         │           │           │
    ┌────▼──┐   ┌───▼───┐  ┌───▼───┐
    │Player1│   │Player2│  │Player3│
    │(LView)│   │(LView)│  │(LView)│
    └───────┘   └───────┘  └───────┘
```

## How It Works

### 1. Player Registration
```elixir
# Player joins
SessionManager.register_player("Alice")

# Returns: {:ok, user, session_id}
# - User struct with ID and username
# - Session ID (automatically allocated)
```

**Process:**
1. Player enters username
2. SessionManager finds an available waiting session
3. If no session exists, creates a new one
4. Adds player to the session
5. Returns session ID to player
6. Player subscribes to session-specific PubSub channel

### 2. Automatic Session Allocation
```elixir
# Find a session with space
waiting_session = find(sessions, fn session ->
  session.status == :waiting && player_count < 10
end)

# If none found, create new session
session_id = generate_session_id()
```

**Logic:**
- Looks for sessions in `:waiting` status with <10 players
- If found: adds player to existing session
- If not found: creates new session for player
- Each session can have up to 10 concurrent players

### 3. Game Start Prevention (No Players)
```elixir
def start_game(session) do
  if map_size(session.players) == 0 do
    # No players - reset to waiting
    %{session | status: :waiting, game_start_time: nil}
  else
    # Has players - start the game
    %{session | status: :playing, ...}
  end
end
```

**Safety Checks:**
- ✅ Before starting game: verify `player_count > 0`
- ✅ UI button disabled if no players present
- ✅ If all players disconnect during countdown: auto-reset to waiting
- ✅ Empty sessions are automatically cleaned up

### 4. Player Disconnection Handling
```elixir
# LiveView terminate callback
def terminate(_reason, socket) do
  if socket.assigns.registered && socket.assigns.session_id do
    SessionManager.remove_player(
      socket.assigns.session_id,
      socket.assigns.user_id
    )
  end
  :ok
end
```

**Cleanup Process:**
1. Player closes browser/tab
2. LiveView `terminate/2` callback fires
3. Player removed from their session
4. Session state updated and broadcast
5. If session becomes empty → marked for cleanup

### 5. Real-Time Synchronization
```elixir
# Session-specific PubSub
Phoenix.PubSub.broadcast(
  TapGame.PubSub,
  "game:session:#{session_id}",
  {:session_state_changed, state}
)
```

**Benefits:**
- Each session has its own PubSub channel
- Only relevant players receive updates
- No cross-session interference
- Reduced broadcast traffic

## Session State Structure

```elixir
%{
  id: "session_abc123...",           # Unique session identifier
  status: :waiting,                   # Game status
  players: %{                         # Map of players in session
    user_id_1 => %{
      username: "Alice",
      tap_count: 0,
      joined_at: ~U[2025-10-07 12:00:00Z]
    },
    user_id_2 => %{
      username: "Bob",
      tap_count: 0,
      joined_at: ~U[2025-10-07 12:00:05Z]
    }
  },
  game_start_time: nil,               # UTC timestamp when game starts
  game_end_time: nil,                 # UTC timestamp when game ends
  created_at: ~U[2025-10-07 11:59:55Z]
}
```

## API Reference

### SessionManager

```elixir
# Register a player (auto-allocates to session)
{:ok, user, session_id} = SessionManager.register_player("username")

# Get current state of a session
{:ok, state} = SessionManager.get_session_state(session_id)

# Record a tap for a player
SessionManager.record_tap(session_id, user_id)

# Manually start a session game
SessionManager.start_session_game(session_id)

# Remove player from session
SessionManager.remove_player(session_id, user_id)
```

### GameSession

```elixir
# Create new session
session = GameSession.new("session_abc123")

# Add player to session
session = GameSession.add_player(session, user)

# Check if can start (has players)
can_start? = GameSession.can_start?(session)  # true/false

# Record tap (only works during :playing)
session = GameSession.record_tap(session, user_id)

# Get public state for broadcasting
public_state = GameSession.get_public_state(session)
```

## Configuration

### Max Players Per Session
Edit `lib/tap_game/session_manager.ex`:
```elixir
# Find waiting session with space
session.status == :waiting && map_size(session.players) < 10  # Change 10
```

### Auto-Start Delay
Edit `lib/tap_game/session_manager.ex`:
```elixir
# Wait time before starting countdown after first player joins
Process.send_after(self(), {:session_event, session_id, :start_countdown}, 5000)  # 5 seconds
```

### Game Duration
Edit `lib/tap_game/game_session.ex`:
```elixir
@game_duration_seconds 15  # Change duration
@countdown_seconds 3       # Change countdown
```

## Testing Multi-Session

### Test 1: Single Session
```bash
# Open 3 tabs
# Tab 1: Join as "Alice" → Gets session_abc123
# Tab 2: Join as "Bob" → Gets session_abc123 (same session)
# Tab 3: Join as "Charlie" → Gets session_abc123 (same session)
# Result: All 3 players in one session
```

### Test 2: Multiple Sessions
```bash
# Open 2 tabs
# Tab 1: Join as "Alice" → Gets session_abc123
# Tab 1: Game starts playing
# Tab 2: Join as "Bob" → Gets session_xyz789 (new session)
# Result: Alice and Bob in different sessions
```

### Test 3: Player Disconnect Safety
```bash
# Tab 1: Join as "Alice"
# Wait for countdown to start
# Close Tab 1 (Alice disconnects)
# Expected: Game resets to waiting (no players left)
```

### Test 4: Cannot Start Without Players
```bash
# Tab 1: Join as "Alice"
# Tab 1: Close immediately (disconnect before countdown)
# Session should reset to :waiting
# UI should show "Waiting for players..." (button disabled)
```

## Benefits of Session-Based System

### ✅ Scalability
- Supports unlimited concurrent games
- Each session isolated from others
- No single point of contention

### ✅ Fairness
- Players only compete within their session
- No cross-session interference
- Fair player allocation

### ✅ Reliability
- Automatic cleanup of empty sessions
- Graceful handling of disconnects
- No orphaned game states

### ✅ User Experience
- Automatic session assignment (no manual selection)
- Clear session identification
- Real-time player count
- Cannot start games with zero players

## Troubleshooting

### Issue: Session not starting
**Check:** Player count in session
```elixir
# In LiveView, check assigns:
@game_state.player_count  # Must be > 0
```

### Issue: Players not seeing each other
**Check:** Are they in the same session?
```elixir
# In LiveView, check:
@session_id  # Should be identical for players in same session
```

### Issue: Session cleanup not happening
**Check:** Player disconnection handling
```elixir
# Ensure terminate/2 is called
# Check SessionManager logs for "removing player" messages
```

## Migration from Single GameServer

The old `GameServer` module has been replaced with:
- ✅ `SessionManager` - Manages multiple sessions
- ✅ `GameSession` - Represents individual session state

**Key Differences:**
| Old (GameServer) | New (SessionManager) |
|-----------------|---------------------|
| Single global game | Multiple concurrent sessions |
| All players in one game | Players auto-allocated to sessions |
| Could start with 0 players | Cannot start without players |
| Manual game coordination | Automatic session management |

## Summary

The new session-based system provides:
1. **Automatic allocation** - Players join available sessions automatically
2. **Multiple games** - Many games can run simultaneously
3. **Safety checks** - Games only start with active players
4. **Clean disconnect handling** - Automatic cleanup when players leave
5. **Real-time updates** - Session-specific PubSub channels
6. **Scalable architecture** - Supports unlimited concurrent sessions

🎮 **Result**: A robust, scalable, multi-player game system that ensures fair gameplay and prevents empty game sessions!

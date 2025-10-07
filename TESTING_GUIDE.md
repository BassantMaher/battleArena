# Testing Guide - Tap Battle Arena

## Prerequisites
- Server running at `http://localhost:3000`
- Multiple browser tabs/windows available

## Test Plan

### Test 1: Single Player Registration ✅

**Steps:**
1. Open browser to `http://localhost:3000`
2. Enter username "TestPlayer1"
3. Click "Join Game"

**Expected Result:**
- Welcome message appears
- Username shown on screen
- Status shows "⏳ Waiting"
- "Start Game Now" button visible

---

### Test 2: Multi-Player Registration ✅

**Steps:**
1. Keep Tab 1 (TestPlayer1) open
2. Open Tab 2 → enter "TestPlayer2" → Join
3. Open Tab 3 → enter "TestPlayer3" → Join

**Expected Result:**
- All tabs show all 3 players
- Player count updates in real-time
- All players see the same information

---

### Test 3: Time Synchronization ✅

**Steps:**
1. With 2+ players registered
2. Click "Start Game Now" in ANY tab
3. Watch all tabs simultaneously

**Expected Result:**
- **All tabs show identical countdown**: 3... 2... 1...
- Countdown appears at the SAME TIME in all tabs
- Game starts simultaneously for all players
- Timer counts down identically in all tabs

**What This Proves:** UTC timestamps + PubSub ensure fair, synchronized start

---

### Test 4: Real-Time Tap Counting ✅

**Steps:**
1. During "PLAYING" phase
2. Click "TAP!" button rapidly in Tab 1
3. Click "TAP!" button slowly in Tab 2
4. Don't click in Tab 3

**Expected Result:**
- Each tab shows its own tap count
- All tabs see ALL players' tap counts update in real-time
- Tap counts are accurate (one tap = one count)
- Leaderboard order updates automatically (highest first)

---

### Test 5: Game End & Winner Announcement ✅

**Steps:**
1. Wait for 15-second timer to reach 0
2. Observe all tabs

**Expected Result:**
- All tabs show "🏆 Game Over! 🏆" at the same time
- Winner is displayed (player with most taps)
- Final scores shown to all players
- Same winner in ALL tabs

---

### Test 6: Leaderboard Persistence ✅

**Steps:**
1. Complete a game
2. Note the top score
3. Refresh the browser (F5)
4. Re-join with same username
5. Check "All-Time Leaderboard"

**Expected Result:**
- Leaderboard shows previous scores
- Top score is still there after refresh
- Scores are sorted (highest to lowest)
- Usernames are displayed correctly

---

### Test 7: Database Verification 🗄️

**Steps:**
1. Open PostgreSQL client or run:
   ```cmd
   cd d:\bassant\Freelancing\task3\tap_game
   mix ecto.psql
   ```
2. Query users:
   ```sql
   SELECT * FROM users;
   ```
3. Query game sessions:
   ```sql
   SELECT * FROM game_sessions ORDER BY tap_count DESC LIMIT 10;
   ```

**Expected Result:**
- Users table contains all registered players
- Game sessions table has records for each game
- Timestamps are in UTC format
- Tap counts match what was displayed

---

### Test 8: Fairness Test (No Cheating) 🛡️

**Attempt to Cheat:**
1. Open browser DevTools (F12)
2. Go to Console
3. Try to manually fire tap events:
   ```javascript
   // Try to cheat by firing multiple events
   for(let i=0; i<1000; i++) {
     document.querySelector('[phx-click="tap"]').click();
   }
   ```

**Expected Result:**
- Server validates each tap
- `phx-throttle="50"` limits tap frequency
- Impossible to get unrealistic scores
- Server controls game state (can't tap when not playing)

---

### Test 9: Timezone Independence 🌍

**Simulate Different Timezones:**

**Option A - Change System Time:**
1. Complete a game
2. Change Windows timezone to different region
3. Play another game

**Option B - Check Timestamps:**
1. After playing, check database:
   ```sql
   SELECT game_started_at, game_ended_at FROM game_sessions;
   ```
2. Verify timestamps are in UTC (not local time)

**Expected Result:**
- Game works identically regardless of local timezone
- All timestamps stored in UTC
- Game duration is exactly 15 seconds for everyone

---

### Test 10: Reconnection & State Recovery 🔄

**Steps:**
1. Start a game with Player1
2. During countdown, close Tab 1
3. Immediately reopen and rejoin as Player1
4. Game should continue

**Expected Result:**
- New session can be created
- Game state is managed server-side
- No disruption to other players

---

### Test 11: Edge Cases 🔍

**Test A: Empty Username**
- Try to join with empty username
- Should show error

**Test B: Duplicate Username**
- Register as "Player1" in Tab 1
- Try to register as "Player1" in Tab 2
- Should succeed (gets existing user)

**Test C: Long Username**
- Try username with 51+ characters
- Should show error (max 50)

**Test D: Rapid Tapping**
- Click TAP button as fast as possible
- Count should increment smoothly
- No missed taps (within throttle limit)

---

## Performance Tests

### Test 12: Many Simultaneous Players 👥

**Steps:**
1. Open 10+ browser tabs
2. Register unique username in each
3. Start game
4. All players tap simultaneously

**Expected Result:**
- System handles all players smoothly
- No lag or delays
- All tap counts update correctly
- No server crashes

---

## Test Results Checklist

Use this checklist to verify all tests:

```
[ ] Test 1: Single Player Registration
[ ] Test 2: Multi-Player Registration  
[ ] Test 3: Time Synchronization
[ ] Test 4: Real-Time Tap Counting
[ ] Test 5: Game End & Winner
[ ] Test 6: Leaderboard Persistence
[ ] Test 7: Database Verification
[ ] Test 8: Fairness (No Cheating)
[ ] Test 9: Timezone Independence
[ ] Test 10: Reconnection
[ ] Test 11: Edge Cases
[ ] Test 12: Many Players
```

---

## Quick Test Script

Run this quick test:

```
1. Open 3 tabs
2. Register: "Alice", "Bob", "Charlie"
3. Click "Start Game Now"
4. Watch synchronized countdown
5. Tap rapidly in each tab
6. Wait for game to end
7. Verify winner is same in all tabs
8. Check leaderboard shows scores
9. Refresh and verify scores persist
```

**If all above pass: ✅ System is working correctly!**

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Server not running | Run `mix phx.server` |
| Port 3000 in use | Change port in `config/dev.exs` |
| Database error | Run `mix ecto.create && mix ecto.migrate` |
| Tabs not syncing | Check if all tabs are connected (WebSocket) |
| Leaderboard empty | Complete at least one full game |

---

## Success Criteria

The game is working correctly if:

✅ All players see synchronized countdown  
✅ Game starts at exact same time for everyone  
✅ Tap counts update in real-time  
✅ Winner is consistent across all clients  
✅ Scores persist after refresh  
✅ Database contains game records  
✅ No client can cheat  
✅ Works regardless of timezone  

---

## Ready to Test!

Start with Test 1 and work through the test plan. The game should pass all tests demonstrating:
- **Real-time synchronization**
- **Fair gameplay across timezones**  
- **Persistent leaderboard**
- **Cheat-proof design**

Happy Testing! 🎮✨

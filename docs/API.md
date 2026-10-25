# OpenBR Network API Reference

All RPCs are defined in `scripts/net.gd`. The server is authoritative; clients send requests, the server validates and broadcasts.

## Client → Server RPCs

### `request_ready_rpc(ready: bool)`
- **Sender:** Client
- **Purpose:** Ready up / cancel ready in lobby.
- **Server handler:** `_on_ready_requested(id, ready)` — sets `players[id]["ready"]`, broadcasts match state.

### `request_input_rpc(dir: Vector2, yaw: float, jump: bool)`
- **Sender:** Client (every frame during LIVE)
- **Purpose:** Send movement input.
- **Server handler:** `_on_input_received(id, dir, yaw, jump)` — stores input, validated for NaN/inf.

### `request_fire_rpc(dir: Vector3)`
- **Sender:** Client
- **Purpose:** Request a shot.
- **Server handler:** `_on_fire_requested(id, dir)` — validates cooldown, ammo, applies damage, broadcasts shot events.

### `request_weapon_rpc(index: int)`
- **Sender:** Client
- **Purpose:** Switch weapon.
- **Server handler:** `_on_weapon_requested(id, index)` — validates, sets weapon + switch_until.

### `request_reload_rpc()`
- **Sender:** Client
- **Purpose:** Reload current weapon.
- **Server handler:** `_on_reload_requested(id)` — calls `_start_reload`.

### `request_loot_rpc(loot_id: int)`
- **Sender:** Client
- **Purpose:** Pick up loot.
- **Server handler:** `_on_loot_requested(id, loot_id)` — validates distance, inventory, broadcasts loot taken + result.

### `request_use_item_rpc(item_type: String)`
- **Sender:** Client
- **Purpose:** Use bandage/medkit.
- **Server handler:** `_on_use_item_requested(id, item_type)` — validates inventory, starts heal.

### `request_emote_rpc(emote_index: int)`
- **Sender:** Client
- **Purpose:** Play emote.
- **Server handler:** `_on_emote_requested(id, emote_index)` — validates alive, broadcasts emote.

### `request_ping_rpc(pos: Vector3)`
- **Sender:** Client
- **Purpose:** Place waypoint marker.
- **Server handler:** `_on_ping_requested(id, pos)` — validates alive, broadcasts ping.

### `request_vehicle_enter_rpc(vehicle_id: int)`
- **Sender:** Client
- **Purpose:** Enter a vehicle.
- **Server handler:** `_on_vehicle_enter_requested(id, vehicle_id)` — sets in_vehicle flag.

### `request_vehicle_exit_rpc(vehicle_id: int)`
- **Sender:** Client
- **Purpose:** Exit a vehicle.
- **Server handler:** `_on_vehicle_exit_requested(id, vehicle_id)` — clears in_vehicle flag.

## Server → Client RPCs

### `apply_spawn(id, pos, appearance)`
- **Purpose:** Spawn local/remote player at position.

### `apply_snapshot(snap, tick, storm)`
- **Purpose:** World state update (positions, health, ammo, etc.).
- **Frequency:** 15 Hz (server), with delta compression (skip unchanged).

### `apply_shot(shooter, from, to, hit, weapon)`
- **Purpose:** Visual tracer + muzzle flash + hit effect.

### `apply_death(victim, killer)`
- **Purpose:** Player death notification.

### `apply_respawn(id, pos)`
- **Purpose:** Respawn (dev mode only).

### `apply_player_gone(id)`
- **Purpose:** Remove remote player.

### `apply_kicked(reason)`
- **Purpose:** Kick notification.

### `apply_match_state(state)`
- **Purpose:** Match lifecycle state (phase, timer, alive count, roster, etc.).

### `apply_loot_state(taken)`
- **Purpose:** Initial loot state on connect.

### `apply_loot_taken(loot_id, by)`
- **Purpose:** Notify loot pickup.

### `apply_loot_spawned(loot_id, type, pos)`
- **Purpose:** Dynamic loot respawn notification.

### `apply_loot_result(message)`
- **Purpose:** Pickup result message for HUD.

### `apply_loot_reset()`
- **Purpose:** Reset loot on match reset.

### `apply_kill_feed(text)`
- **Purpose:** Kill feed entry.

### `apply_battle_pass_update(xp, tier)`
- **Purpose:** Battle Pass XP/tier update.

### `apply_emote(player_id, emote_index)`
- **Purpose:** Show emote on player.

### `apply_ping(player_id, pos)`
- **Purpose:** Show waypoint marker.

## Signals (net.gd)
All signals are emitted by net.gd and connected in client/main.gd and server/main.gd.
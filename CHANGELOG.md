# Changelog

All notable changes to OpenBR are documented here.

## [0.3.0] - 2026-10-25

### Added
- **Game Design**: Sniper, Grenade, Rocket, Melee weapons + explosive area damage.
- **Game Design**: Emote system (5 emotes, keys 1-5, server broadcast).
- **Game Design**: Dynamic Events — Supply Crates (armor + medkit + ammo + bandage).
- **Game Design**: Ping System (waypoint markers, key P / middle mouse).
- **Game Design**: Squad Mode (`--squad-size=1-4`, teams, friendly fire, team win).
- **Game Design**: Vehicles (VehicleBody3D scene, enter/exit RPCs).
- **Game Design**: Battle Pass (XP tracking, 50 tiers, cosmetic rewards).
- **Technical**: Delta Compression (skip unchanged snapshots, keyframe every 10 ticks).
- **Technical**: LOD System (visibility_range on meshes).
- **Technical**: MultiMesh Instancing (scatter props).
- **Technical**: Occlusion Culling (BoxOccluder3D).
- **Technical**: Server-Side Anti-Cheat (speed clamp, fire rate validation).
- **Technical**: Replay System (record/playback to `user://replays/`).
- **Technical**: `--storm-scale=N` argument.
- **Technical**: 100+ player scaling (MAX_PLAYERS 128, BOT_MAX 32, INTEREST_RADIUS 35m, map 200×200m, 100 loot spawns, dynamic loot respawn).
- **Visuals**: Water shader, grass/foliage, muzzle flash, hit sparks, weather system.
- **Visuals (Cartoon)**: Toon shader, outlines, storm/safezone shaders, WorldEnvironment, DirectionalLight3D.
- **Infrastructure**: Docker (server + matchmaker), matchmaker HTTP service, analytics logging.
- **Documentation**: API reference, contributing guide, changelog.

### Changed
- `SNAPSHOT_HZ`: 20.0 → 15.0
- `STORM_START_RADIUS`: 54.0 → 85.0
- `INTEREST_RADIUS`: 45.0 → 35.0
- `MAX_PLAYERS`: 64 → 128
- `BOT_MAX`: 16 → 32
- Loot touch radius: 40 → 48
- Renderer: `forward_plus` → `gl_compatibility`

### Fixed
- Lobby header profile label autowrap on 720p screens.
- Ping/emote RPCs serialized `Vector3` as 3 floats (Godot RPC), fixing `Method expected 1 arguments`.
- Emote list typed as `Array[String]` so `emote_text` infers `String`.
- `hit_effect.gd` now parents sparks before `look_at` and uses `global_position`.
- `Net.reject()` no longer calls `get_peer()` on a peer that already left (engine error spam).
- Client now reports an unreachable server after 8s instead of waiting ~32s for the ENet timeout.
- Connect failures now name the cause (`could not reach host:port` vs `no response after 8s`).
- Touch UI gained **PING** and **EMOTE** buttons; both systems were unreachable on Android before.
- Export presets exclude `build/` so dev screenshots are no longer packed into APK/AAB.

## [0.2.0] - 2026-10-24

### Added
- Phase 1: Battle Royale match lifecycle (WAITING/COUNTDOWN/LIVE/ENDED).
- One life per match, last-player-standing victory, placement, spectator, kill feed.
- Storm only during LIVE, no late join during live match.
- Per-match loot reset, spectator snapshots, client match panel.
- Ready-up guard (700ms), FOCUS_NONE buttons.
- Loot field hidden outside LIVE.

### Changed
- AAB minSdk fixed to 21.
- Storm: 54→38, 38→22, 22→10, final 10. DPS 2/4/6/8.
- Armor absorbs 55% weapon damage; storm bypasses armor.
- Bandage 25 HP/2s, medkit 60 HP/4s.

## [0.1.0] - 2026-10-23

### Added
- Initial prototype: Godot 4.4 client, Go matchmaker, Android builds.
- Verdant Reach map (120×120m, 9 regions, 9 spawn points).
- 69 loot spawns, 3 weapons (Rifle, SMG, Shotgun).
- Server-authoritative movement/combat/loot/inventory/armor/healing.
- 30 Hz server tick, 20 Hz snapshots.
- Android: ARM64, org.openbr.game, gl_compatibility, sensor landscape, INTERNET.
- Dev auth, bots, auto-start, dev-respawn flags.
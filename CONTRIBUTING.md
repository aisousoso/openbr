# Contributing to OpenBR

Thank you for your interest in contributing! OpenBR is an open-source Battle Royale prototype built with Godot 4.4.1.

## Getting Started

1. Fork the repository: https://github.com/aisousoso/openbr
2. Clone your fork: `git clone https://github.com/<you>/openbr.git`
3. Create a branch: `git checkout -b feature/my-feature`
4. Make changes in `D:\tagriba2\openbr` (or your clone path)
5. Commit: `git commit -m "Add my feature"`
6. Push: `git push origin feature/my-feature`
7. Open a Pull Request

## Project Structure

```
openbr/
├── client/          # Godot client (scenes, scripts, UI)
├── server/          # Headless dedicated server
├── shared/          # Shared data (weapons, loot, characters, map data)
├── maps/            # Map scenes and builders
├── scripts/         # Networking facade (net.gd)
├── assets/          # (empty — all visuals are procedural)
├── docs/            # Documentation
├── .github/         # CI/CD workflows
└── project.godot    # Godot project config
```

## Rules

### Code
- Use Godot 4 syntax only.
- Server is authoritative — never trust client input.
- Do not change gameplay logic when working on visuals.
- Keep changes small and commented.
- Follow existing code style (tabs, GDScript conventions).

### Assets
- Code: MIT License
- Assets: CC0 or CC-BY with attribution
- No copyrighted content (no Free Fire Max clones)
- No IAP bypass, paid-skin unlock, anti-cheat evasion

### Server
- Server and matchmaker stay on PC/VPS/Docker — never in APK/AAB.
- Never embed `BR_SECRET` in the client.
- Tokens come from the matchmaker.

### Android
- APK/AAB contains client only.
- `export_presets.cfg` is gitignored — use `.example` template.
- ARM64, `org.openbr.game`, `gl_compatibility`, sensor landscape, `INTERNET`.

## Testing

### Headless Tests
```bash
# Match lifecycle
godot --headless --path . res://server/main.tscn -- --dev-auth --bots=3 --auto-start --countdown=1 --min-players=2 --end-delay=4 --run-seconds=20

# Client
godot --headless --path . res://client/main.tscn -- --host=127.0.0.1 --port=7777 --token=dev --run-seconds=17
```

### Android
```powershell
powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1
```

## Commit Messages
Use conventional commits:
- `feat: add sniper weapon`
- `fix: lobby header autowrap on 720p`
- `docs: update API reference`
- `perf: reduce snapshot rate to 15Hz`

## Pull Request Checklist
- [ ] Code compiles (Godot headless runs without errors)
- [ ] No gameplay logic changed (unless intended)
- [ ] Server code unchanged (unless intended)
- [ ] Docs updated if needed
- [ ] Tested on desktop (and MEmu if possible)

## Contact
- GitHub: https://github.com/aisousoso/openbr
- Issues: https://github.com/aisousoso/openbr/issues
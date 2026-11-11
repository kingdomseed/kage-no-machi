# Agent instructions for Kage no Machi

Read [docs/direction.md](docs/direction.md) and [docs/glossary.md](docs/glossary.md) before changing code, shaders, UI labels, or documentation. Keep both files updated whenever product direction or terminology changes.

## Model division of labor

Only Carbon, Argon, and Flash 3.8 are used in this workspace:

- **Carbon (`inherit` on Gemini 4 Carbon High):** Owns all visual art direction, 3D procedural geometry, `.fmat` and post-processing shaders, screenshot evaluation against `docs/references/shadow-tactics/`, UX design, deep research, and orchestration. Never delegate visual taste or complex 3D spatial work away from Carbon.
- **Argon (`pro` on Gemini 4 Argon High):** Assists with bounded systems plumbing, tests, and static or runtime verification. Carbon inspects every Argon diff and visually verifies rendered results.
- **Flash 3.8 (`flash`):** Performs fast search and file retrieval.

## Active scope

- Focus on **tactile Edo city building** and **pushing the painted diorama look** toward `docs/references/shadow-tactics/st-01.jpg` through `st-10.jpg`.
- Keep watchtowers, sightcones, and stealth mechanics parked out of the active HUD and gameplay loop until explicitly resumed in [docs/direction.md](docs/direction.md).
- Never modify `macos/Runner/DebugProfile.entitlements`.

## Mandatory verification

1. Run `flutter analyze` and `flutter test` to zero warnings and zero failures.
2. Run macOS Metal captures with `flutter run -d macos --enable-flutter-gpu --dart-define=SHUKUBA_CAPTURE_DIR=/tmp/shukuba_cap --dart-define=SHUKUBA_AUTO_EXIT=true`.
3. Confirm `coplanarOverlapCount == 0` and `depthConflictCount == 0` across all presets in `summary.json`, and have Carbon visually inspect the captured PNGs directly against `docs/references/shadow-tactics/`.

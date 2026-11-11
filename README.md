# Kage no Machi

*Kage no Machi* is an atmospheric isometric Edo post-town (*shukuba*) diorama builder built with `flutter_scene` `0.24.3`, `flutter_scene_soloud` `0.2.0`, and Flutter GPU on macOS Metal.

See [docs/direction.md](docs/direction.md) for current product and visual direction and [docs/glossary.md](docs/glossary.md) for Edo architectural, musical, and rendering terminology.

## Run on macOS Metal

```sh
flutter run -d macos --enable-flutter-gpu
```

`--enable-flutter-gpu` is the only required engine flag.

## Controls

- **Select a tool** on the bottom build bar:
  - **Stamp tools** (`Townhouse`, `Teahouse`, `Storehouse`, `Market Stall`, `Lantern Gate`, `Maple & Rocks`, `Bamboo Grove`): move the cursor over the terrain to preview the snapped 3D footprint and lantern connections, press `R` to rotate in 45-degree steps, and **left-click** to build.
  - **Paint tools** (`Cobble Lane`, `Stone Terrace`, `Courtyard Wall`): **left-press and drag** across the terrain to draw a live 3D ribbon, then release to build.
  - **Edit tools** (`Demolish`, `Undo`): select `Demolish` and left-click a highlighted building, wall, terrace, or lane to remove it, or click `Undo` (`Z`) to revert the last change.
- **Move the camera:**
  - **Pan:** right-drag, middle-drag, `Space` + left-drag, or `WASD` and arrow keys.
  - **Orbit:** `Q` and `E`.
  - **Zoom:** scroll wheel or trackpad scroll.
  - **Presets and lighting:** use `1`, `2`, `3` or the top-left camera chips, and drag the top-right time slider between **Golden Dusk** (*Yo* scale) and **Blue Hour Night** (*In-sen* scale).

## Static analysis, tests, and automated Metal captures

```sh
flutter analyze
flutter test
flutter run -d macos --enable-flutter-gpu \
  --dart-define=SHUKUBA_CAPTURE_DIR=/tmp/shukuba_captures \
  --dart-define=SHUKUBA_AUTO_EXIT=true
```

# Kage no Machi (影の町)

*Kage no Machi* is an atmospheric isometric Edo post-town (*shukuba*) diorama builder built on Flutter `3.50.0`, Flutter GPU, `flutter_scene` `0.24.3`, and `flutter_scene_soloud` `0.2.0` for macOS Metal. Shape a riverside highway settlement from golden dusk into blue-hour night while buildings, roads, garden paths, terraces, trees, and shrines respond with spatial pentatonic instruments.

> Canonical screenshots and a short showcase video will be added soon.

## Highlights

- **Procedural four-sided Edo carpentry & cycling silhouettes:** Every structure frames all four exterior elevations with *hashira* posts, *nuki* tie beams, *shitami-ita* cedar siding, *tobukuro* shutter boxes, and *kutsunugi-ishi* threshold steps, cycling automatically across four *machiya* townhouse silhouettes, four *minka* farmhouses, three *chaya* teahouses, three *kura* storehouses, and four *yatai* market stalls.
- **Physical sky IBL, PCSS shadows & *komorebi* god rays:** `PhysicalSkySource`, `SkyEnvironment`, and `Skybox` drive a 4-cascade `DirectionalLight` with percentage-closer soft shadows (`DirectionalShadowFilter.pcss`), screen-space contact shadows, 64-step volumetric *komorebi* sunbeams, and at most 12 clustered lantern `PointLight` pools.
- **Mip-filtered 4-step parallax relief (`gouache_lit.fmat`):** Analytical `fwidth` mip weighting, a 4-step view-ray heightfield, 2-tap directional micro-horizon self-shadowing, and cavity occlusion pair with bent-normal GTAO and the `SumiInkPass` post-process.
- **Refractive Beer-Lambert riverbed caustics (`river_water.fmat`):** Samples `scene_color` and `scene_depth` with `GetSceneWorldPosition` for Gerstner wave refraction, Beer-Lambert depth absorption, and dual-layer cellular riverbed caustics.
- **`4 x 4` chunked terrain & `flora_tile_r_c` undergrowth:** A `176 m x 176 m` contour-aligned terrain grid and sixteen `44 m x 44 m` instanced flora chunks scatter 9-frond clover/fern/moss rosettes, *susuki* plumes, wildflowers, river reeds, and outer groves while rebuilding only dirty chunks on edits.
- **Falling *momiji* & *ichō* autumn leaves on the *urushi* Title Menu:** Animated Japanese maple (*momiji*) and ginkgo (*ichō*) leaves drift across *kinpaku* gold flecks on the smoked-lacquer **Title Menu** (respecting reduced-motion preferences), while the in-valley HUD keeps clean single-line `32 px` buttons with shortcuts moved to hover tooltips.
- **Licensed Japanese music & spatial pentatonic soundscape:** Traditional Japanese background music (`music_shukuba.ogg`) plays on the Title Menu and Valley `_musicBus`, layered over gentle natural river, wind, and cricket field loops and `D4`-calibrated instruments (*koto*, *shakuhachi*, *hyōshigi*, *bonshō*) shifting from the *Yo* scale at dusk to *In-sen* at night.

## Requirements

- macOS with Metal support
- Flutter `3.50.0`+ (Dart SDK `^3.14.0`)

## Quick start

```sh
git clone https://github.com/kingdomseed/kage-no-machi.git
cd kage-no-machi
flutter pub get
flutter run -d macos --enable-flutter-gpu
```

`--enable-flutter-gpu` is the only required engine flag.

## Controls

HUD buttons keep clean labels without inline key brackets; keyboard shortcuts appear in hover tooltips and below.

| Action | Input |
| :--- | :--- |
| **Camera views (1–6)** | `1`–`6` or **Views** in the top-left bar |
| **Pan camera** | `WASD`, arrow keys, middle-drag, `Space` + left-drag, or left-drag when exploring |
| **Orbit camera** | Right-drag, `Q`, or `E` |
| **Zoom camera** | Scroll wheel or trackpad scroll |
| **Place / draw tool** | Left-click to place stamps; left-drag to draw roads, paths, terraces, and walls |
| **Cycle Style** | `V` (or **Style** in the guidance bar; advances automatically on placement) |
| **Rotate stamp (45°)** | `R` (or **Rotate** in the guidance bar) |
| **Undo** | `Z` (or **Undo** in the bottom dock) |
| **Demolish** | `Del` / `Backspace` / `X` (or **Demolish** in the bottom dock) |
| **Commit Stroke** | `Enter` (or **Build** in the guidance bar) |
| **Exit Tool / Pause** | `Esc` (cancels active stroke, exits active tool, or opens the **Pause Menu**) |
| **Telemetry overlay** | `F3` |

## Verification

```sh
flutter analyze
flutter test
flutter run -d macos --enable-flutter-gpu \
  --dart-define=SHUKUBA_CAPTURE_DIR=/tmp/shukuba_captures \
  --dart-define=SHUKUBA_AUTO_EXIT=true
```

## Documentation & licensing

- [docs/direction.md](docs/direction.md) — product direction, rendering architecture, and visual evaluation loop
- [docs/glossary.md](docs/glossary.md) — Edo architectural, musical, UI, and `flutter_scene` terminology
- [LICENSE](LICENSE) — MIT License
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — audio asset attributions and permissive licenses

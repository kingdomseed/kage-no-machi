# Kage no Machi direction

*Kage no Machi* is an atmospheric isometric Edo post-town builder running on `flutter_scene` `0.24.3`, `flutter_scene_soloud` `0.2.0`, and macOS Metal. You shape a riverside highway post-town, or *shukuba*, from golden dusk into blue-hour night while every road, garden path, stone terrace, wall, rock outcrop, cottage, shop, shrine, and tree responds with spatial pentatonic instruments.

## Visual commitment to fine-detail painted diorama (Direction B)

*Kage no Machi* commits to **Direction B**, a fine-detail painted diorama built procedurally in code rather than a flat low-poly toy look. Visual scale, surface weathering, and composition anchor on `docs/references/shadow-tactics/st-01.jpg` through `st-25.jpg` and historical Azuchi-Momoyama and early Edo village carpentry.

1. **Human-scale 4-sided Edo carpentry, varied roofs, and towering botanical contrast.** Dwellings scale intimately around `1.66 m` townsfolk (`~1.8 m` doorway lintels and `3.1 m` to `4.5 m` roof ridges) while jointed bamboo groves (`9.5 m` to `13.5 m`), black pines, *sugi* cedars, and autumn maples (`7.8 m` to `11.2 m`) rise two to three times higher overhead. Every building frames all four exterior elevations with post-and-beam bays (*hashira* and *nuki*), horizontal *shitami-ita* weatherboarding, *tobukuro* shutter boxes, hooded side windows, rear service doors, *mushiko-mado* loft grilles, and additive kitchen or veranda wings. Roofs vary across hand-dipped variegated *kawara* clay tiles, concave *irimoya* shrine gables, river-cobble-weighted *ishi-oki-yane* cedar shingles with rooftop *hoshidai* decks, and mossy golden *kayabuki* reed thatch on vernacular *minka* cottages.
2. **Restrained ground flora, fractured layered stone, and churned dirt.** Roughly three-quarters of the valley floor stays calm, richly textured earth, damp moss, wheel-rutted ochre clay, embedded pebbles, and low-roughness puddles in [`TerrainBuilder`](../lib/shukuba/world/terrain_builder.dart) and [`gouache_lit.fmat`](../assets/materials/gouache_lit.fmat). Natural *iwa* rock outcrops stay at grounded outcrop heights (`1.4 m` to `2.6 m`) with deep cellular fractures, warm sunlit ochre crowns, cool slate shadow bellies, and mossy pockets. [`FloraScatterBuilder`](../lib/shukuba/world/flora_scatter_builder.dart) concentrates 3D grass tufts, *susuki* plumes, *nogiku* wildflowers, crimson *higanbana*, wall drapes, and riverside *ashi* reeds into habitat pockets hugging walls, boulders, tree skirts, and water margins through [`living_meadow.fmat`](../assets/materials/living_meadow.fmat).
3. **Sculpted multi-tier elevation, terraced countryside, velvety shadows, and street festival life.** Terrain uses a `0.5 m` contour-aligned mesh tiled across a `4 x 4` spatial chunk grid spanning a `176 m x 176 m` valley so riverbanks, berms, curved *tanada* rice paddies, *mitsuke* highway checkpoints, and retained [`TerraceCourse`](../lib/shukuba/model/shukuba_types.dart) plateaus grade smoothly into battered *ishigaki* walls, *sangi-zumi* corner quoins, and walkable *kaidan* staircases. Low shadow ambient fill and wide GTAO ground every overhang in cool Prussian-indigo shadow pools. Market plazas and temple terraces come alive with multi-color striped *yatai* stalls, overhead *fukinagashi* festival streamers on catenary cords, red *wagasa* umbrellas, wooden water tubs, plank duckboards, roofed *ido* courtyard wells, raked *karesansui* gravel courts, and a timber *shōrō* bell pavilion.
4. **Instant woodblock UI shell, phased loading telemetry, dirty-tile chunking, and tactile building.** Startup paints a woodblock and *urushi* lacquer Title Menu immediately while audio WAV synthesis runs on a background isolate, then advances through a stage-timed Loading Curtain and hidden GPU pipeline warmup before revealing the valley. Editing a road, terrace, wall, or building invalidates only intersecting `44 m x 44 m` terrain and flora chunks. Right-click drag orbits yaw and pitch smoothly, `Esc` opens settings and field notes, `F3` toggles live boot and frame telemetry, and categorized ink-icon docks drive snapped footprints, Catmull-Rom road and wall splines, demolish, and undo.

## Parked systems for watchtowers and stealth intrigue

Watchtowers, Magistrate's Eye sightcone decals, and nighttime smuggling mechanics remain parked while we finish visual craft, UI polish, and valley expansion. Low-level `DecalNode` shader support stays in the repository for future use, while watchtowers and vision-cone overlays remain out of the active HUD, starter ward, and player toolset.

## Visual evaluation loop

Every rendering, shader, or geometry change follows a closed Metal screenshot loop:

1. Capture settled `1440x778` frames across dusk, blue-hour night, river-crossing, meadow close-up, motion-offset, and countryside-vista camera angles with `ShukubaFrameHarness`, confirming zero coplanar overlaps and zero perturbed depth conflicts.
2. Inspect the captured PNGs directly side by side against `docs/references/shadow-tactics/st-01.jpg` through `st-25.jpg`.
3. Check house-to-person proportions, 4-sided exterior carpentry, roof material variety, towering tree-to-house contrast, fractured rock and rutted dirt normal relief, shadow depth, festival streamers, and shrine courtyard details before accepting the change.

## Model roles

Work in this repository follows strict model ownership:

- **Carbon** owns all 3D geometry, `.fmat` and post-processing shaders, visual evaluation against the reference corpus, UX design, deep research, and orchestration.
- **Argon** assists with bounded systems plumbing, unit tests, and code or static-analysis validation, always reviewed and visually verified by Carbon.
- **Flash 3.8** handles fast file search and reference retrieval.

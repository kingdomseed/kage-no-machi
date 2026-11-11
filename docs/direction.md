# Kage no Machi direction

*Kage no Machi* is an atmospheric isometric Edo post-town builder running on `flutter_scene` `0.24.3`, `flutter_scene_soloud` `0.2.0`, and macOS Metal. Players shape a riverside highway post-town, or *shukuba*, from golden dusk into blue-hour night while every road, wall, shop, and tree responds with spatial pentatonic instruments.

## Visual commitment: fine-detail painted diorama (Direction B)

*Kage no Machi* commits to **Direction B**, a fine-detail painted diorama built procedurally in code rather than a flat low-poly toy look. All visual choices anchor on the ten reference frames in `docs/references/shadow-tactics/st-01.jpg` through `st-10.jpg`.

1. **Living multi-species ecosystem and 75,000-element meadow.** Terrain blends worn ochre dirt shoulders, wheel ruts, damp plinth moss, and wet riverbank silt in [`TerrainBuilder`](../lib/shukuba/world/terrain_builder.dart) and [`gouache_lit.fmat`](../assets/materials/gouache_lit.fmat). Trees never repeat static clones. Each *momiji* maple, jointed bamboo grove, gnarled *kuromatsu* black pine, and riverside *yanagi* weeping willow hashes its placement seed to vary trunk lean, curved multi-segment boughs, buttress roots, and `alpha_to_coverage` canopy tiers in [`foliage_canopy.fmat`](../assets/materials/foliage_canopy.fmat). Across the hillsides and riverbanks, [`FloraScatterBuilder`](../lib/shukuba/world/flora_scatter_builder.dart) drives over 75,000 curved 3D grass blades, feathery *susuki* pampas plumes, dimensional white and pale-lavender *nogiku* wildflowers, crimson *higanbana* spider lilies, *ishigaki* wall-crest drapes, woodland ferns, and floating river leaves through [`living_meadow.fmat`](../assets/materials/living_meadow.fmat), all bending in unison to a traveling 2D valley wind-gust field.
2. **Living air, mist, and evening dew.** The air between camera and ground carries visible moisture and light rather than uniform distance fog. Depth-softened mist ribbons curl up from the river gorge and pool in low alleys, directional dusk sunbeams filter through tree crowns, and warm atmospheric halos surround lit *chōchin* lanterns at night. GPU-drifted instanced motes shift from sunlit pollen and tumbling maple leaves at dusk to glinting dew motes, teahouse steam wisps, and riverside *hotaru* fireflies at night, while `TimeOfDayRig.dewFactor` lowers evening surface roughness so roof tiles, cobbles, and bridge planks catch cool damp sky reflections.
3. **Tactile Edo architecture and micro-life.** Buildings combine corrugated *kawara* tile ribs, lower street-level *hisashi* porch roofs, side-wall *shitami-ita* weatherboarding and *nuki* tie-beams, wooden *kōshi* lattices, wind-swaying cloth *noren* curtains, and fluttering *nobori* shop banners. Submerged boulders and bridge pilings shed concentric water ripples, thresholds gather barrels, crates, handcarts, and stone *tōrō* lanterns, and kimono-clad townsfolk walk the highway with layered *haori* sleeves, travel packs, and handheld lanterns.
4. **Self-explanatory musical building.** The viewport opens in free camera (`ExploreTool`) so moving the cursor never draws stray ghosts until you select a tool card on the bottom dock. Active stamp tools show a crisp ground-footprint sill, doorway chevron, corner stakes, and preview catenary lantern cords. Linear tools paint lanes, stone terraces, and tiled *hei* walls by left-dragging a live 3D ribbon, paired with one-click demolish, undo, and spatial `koto`, `shakuhachi`, `hyōshigi`, and `bonshō` notes quantized to *Yo* (day) and *In-sen* (night) scales.

## Parked systems: watchtowers and stealth intrigue

Watchtowers, Magistrate's Eye sightcone decals, and nighttime smuggling mechanics remain parked while we finish the visual craft and city-building loop. Low-level `DecalNode` shader support stays in the repository for future use, while watchtowers and vision-cone overlays remain out of the active HUD, starter ward, and player toolset.

## Visual evaluation loop

Every rendering, shader, or geometry change follows a closed Metal screenshot loop:

1. Capture settled `1440x778` frames across dusk, blue-hour night, and river-crossing camera angles with `ShukubaFrameHarness`, confirming zero coplanar overlaps and zero perturbed depth conflicts.
2. Inspect the captured PNGs directly side by side against `docs/references/shadow-tactics/st-01.jpg`, `st-03.jpg`, `st-05.jpg`, `st-06.jpg`, `st-08.jpg`, and `st-10.jpg`.
3. Check botanical silhouette delicacy, perforated ground shadows, ground wear transitions, rising river mist, evening dew sheen, water wakes, and warm-against-cool lantern contrast before accepting the change.

## Model roles

Work in this repository follows strict model ownership:

- **Carbon:** Owns all 3D geometry, `.fmat` and post-processing shaders, visual evaluation against the *Shadow Tactics* reference corpus, UX design, deep research, and orchestration.
- **Argon:** Assists with bounded systems plumbing, unit tests, and code or static-analysis validation, always reviewed and visually verified by Carbon.
- **Flash 3.8:** Handles fast file search and reference retrieval.

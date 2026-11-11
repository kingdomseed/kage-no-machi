# Kage no Machi direction

*Kage no Machi* is an atmospheric isometric Edo post-town builder running on `flutter_scene` `0.24.3`, `flutter_scene_soloud` `0.2.0`, and macOS Metal. Players shape a riverside highway post-town, or *shukuba*, from golden dusk into blue-hour night while every road, wall, shop, and tree responds with spatial pentatonic instruments.

## Current focus: tactile Edo city building and painted look

We build and validate the core town-building experience and visual craft before layering tactical or stealth systems on top.

1. **Self-explanatory tactile building.** The viewport opens in free camera (`ExploreTool`) so moving the cursor around the town never paints stray ghosts until you choose a tool on the bottom dock (clicking an active card again or pressing `Esc` returns to free camera). When a build tool is active, hovering shows a crisp ground-footprint frame, doorway direction chevron, corner stakes, and preview arcs for any catenary lantern spans it will form with neighboring eaves. Linear tools such as lanes, stone terraces, and tiled courtyard walls paint directly on the ground by clicking and dragging with a live 3D ribbon, accompanied by one-click demolish and undo.
2. **Painted *Shadow Tactics* diorama craft.** Our visual target comes exclusively from the ten reference frames in `docs/references/shadow-tactics/st-01.jpg` through `st-10.jpg`. Surfaces rely on tactile architectural relief rather than smooth untextured boxes: corrugated *kawara* tile ribs, lower street-level *hisashi* porch roofs, side-wall *shitami-ita* weatherboarding and *nuki* tie-beams, wooden *kōshi* lattices, cloth *noren* shop curtains, stone-curbed *kaidō* lanes, fitted *ishigaki* stone retaining walls, cross-planked bridges, sunken riverside boulder clusters in a jade mountain stream, slender branching maples, thin-culm bamboo, distance-attenuated sumi-gouache ink contours, and cool valley mist pooling in the river gorge.
3. **Contextual street life.** Stamping buildings along a lane or enclosing courtyards with tiled *hei* walls populates thresholds with non-overlapping Edo micro-props such as stacked sake barrels, crates, handcarts, stone *tōrō* lanterns, and stepping stones.
4. **Musical townscaping.** Placing structures and paths triggers synthesized 3D `koto`, `shakuhachi`, `hyōshigi`, and `bonshō` notes quantized to the daytime *Yo* pentatonic scale and the nighttime *In-sen* pentatonic scale over spatial river, wind, and cricket loops.

## Parked systems: watchtowers and stealth intrigue

Watchtowers, Magistrate's Eye sightcone decals, and nighttime smuggling mechanics are parked while we establish the visual look and city-building loop. Low-level `DecalNode` shader support remains in the repository for future use, but watchtowers and vision-cone overlays stay out of the active HUD, starter ward, and player toolset until we choose how stealth or intrigue joins the town simulation.

## Visual evaluation loop

Every rendering, shader, or geometry change follows a closed Metal screenshot loop:

1. Capture settled `1440x778` frames across dusk, blue-hour night, and river-crossing camera angles using `ShukubaFrameHarness`, verifying zero coplanar overlaps and zero perturbed depth conflicts.
2. Inspect the captured PNGs directly side by side against `docs/references/shadow-tactics/st-01.jpg`, `st-03.jpg`, `st-05.jpg`, `st-06.jpg`, `st-08.jpg`, and `st-10.jpg`.
3. Evaluate material relief, roofline layering, foliage delicacy, ground grounding, river flow direction, and warm-against-cool lighting contrast before accepting the change.

## Model roles

Work in this repository follows strict model ownership:

- **Carbon:** Owns all 3D geometry, `.fmat` and post-processing shaders, visual evaluation against the *Shadow Tactics* reference corpus, UX design, deep research, and orchestration.
- **Argon:** Assists with bounded systems plumbing, unit tests, and code or static-analysis validation, always reviewed and visually verified by Carbon.
- **Flash 3.8:** Handles fast file search and reference retrieval.

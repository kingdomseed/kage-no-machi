# Kage no Machi direction

*Kage no Machi* is an atmospheric isometric Edo post-town builder running on `flutter_scene` `0.24.3`, `flutter_scene_soloud` `0.2.0`, and macOS Metal. Players shape a riverside highway post-town, or *shukuba*, from golden dusk into blue-hour night while every road, garden path, stone terrace, wall, rock outcrop, shop, and tree responds with spatial pentatonic instruments.

## Visual commitment: fine-detail painted diorama (Direction B)

*Kage no Machi* commits to **Direction B**, a fine-detail painted diorama built procedurally in code rather than a flat low-poly toy look. All visual and compositional choices anchor on `docs/references/shadow-tactics/st-01.jpg` through `st-10.jpg`.

1. **Restrained *Shadow Tactics* ground composition and multi-species Edo flora.** Roughly three-quarters of the valley floor stays calm, richly painted bare earth, damp moss, wheel-rutted ochre sand, gravel, and fallen leaves in [`TerrainBuilder`](../lib/shukuba/world/terrain_builder.dart) and [`gouache_lit.fmat`](../assets/materials/gouache_lit.fmat) so roads, rocks, and silhouettes read clearly at isometric height. [`FloraScatterBuilder`](../lib/shukuba/world/flora_scatter_builder.dart) concentrates 3D curved grass tufts, *susuki* plumes, *nogiku* wildflowers, crimson *higanbana*, wall drapes, and riverside *ashi* reeds into intentional habitat pockets hugging walls, rock bases, tree skirts, and water margins through [`living_meadow.fmat`](../assets/materials/living_meadow.fmat), breathing with a slow, quiet ambient drift rather than artificial wind waves. Each *momiji* maple, jointed bamboo grove, gnarled *kuromatsu* black pine, riverside *yanagi* weeping willow, and layered *iwa* rock outcrop hashes its placement seed to vary form and color without cloned repeats.
2. **Sculpted multi-tier elevation, retained *ishigaki*, and curving roads.** Terrain uses a `0.5 m` contour-aligned mesh tiled across spatial nodes so riverbanks, earthen berms, and retained [`TerraceCourse`](../lib/shukuba/model/shukuba_types.dart) plateaus grade smoothly without sawtooth grid steps or freestanding wall slabs. Battered castle-stone *ishigaki* walls carry 3D *sangi-zumi* corner quoins, irregular capstones, anchor boulders, and stepped *kaidan* staircases wherever roads cross an elevation rise, while river gorges step down through layered cliff strata and *shigarami* timber bank pilings. Players draw smooth Catmull-Rom **Roads** (*Kaidō* packed earth with cart ruts and 3D stone border curbs) and **Garden Paths** (*Roji* raked gravel with 3D *tobi-ishi* stepping stones).
3. **Living air, mist, evening dew, and street micro-life.** Depth-softened mist ribbons curl up from the river gorge and pool in low alleys, warm atmospheric halos surround lit *chōchin* lanterns at night, and GPU-drifted motes shift from dusk pollen and falling leaves to evening dew motes, teahouse steam wisps, and riverside *hotaru* fireflies while `TimeOfDayRig.dewFactor` dampens roof tiles, cobbles, and bridge planks. Buildings gather DNA-varied *komodaru* sake barrel racks, two-wheeled *daihachi-guruma* handcarts, stacked firewood, stone *tōrō* lanterns, swaying cloth *noren*, and *nobori* banners while kimono-clad townsfolk walk the highway.
4. **Tactile camera and self-explanatory musical building.** Right-click and hold orbits yaw and pitch smoothly around the view target while left-drag (in `ExploreTool`), middle-drag, `Space`+drag, and `WASD` pan across the valley. Active stamp tools preview snapped footprints, doorway chevrons, and catenary lantern cords; linear tools paint smooth spline ribbons for roads, garden paths, stone terraces, and tiled *hei* walls, paired with one-click demolish, undo, and spatial `koto`, `shakuhachi`, `hyōshigi`, and `bonshō` notes quantized to *Yo* (day) and *In-sen* (night) scales.

## Parked systems: watchtowers and stealth intrigue

Watchtowers, Magistrate's Eye sightcone decals, and nighttime smuggling mechanics remain parked while we finish the visual craft and city-building loop. Low-level `DecalNode` shader support stays in the repository for future use, while watchtowers and vision-cone overlays remain out of the active HUD, starter ward, and player toolset.

## Visual evaluation loop

Every rendering, shader, or geometry change follows a closed Metal screenshot loop:

1. Capture settled `1440x778` frames across dusk, blue-hour night, river-crossing, and close-up camera angles with `ShukubaFrameHarness`, confirming zero coplanar overlaps and zero perturbed depth conflicts.
2. Inspect the captured PNGs directly side by side against `docs/references/shadow-tactics/st-01.jpg` through `st-10.jpg`.
3. Check ground-to-foliage restraint, multi-tier stone and cliff step-downs, road and stepping-path curvature, building threshold clutter, rising river mist, evening dew sheen, and warm-against-cool lantern contrast before accepting the change.

## Model roles

Work in this repository follows strict model ownership:

- **Carbon:** Owns all 3D geometry, `.fmat` and post-processing shaders, visual evaluation against the *Shadow Tactics* reference corpus, UX design, deep research, and orchestration.
- **Argon:** Assists with bounded systems plumbing, unit tests, and code or static-analysis validation, always reviewed and visually verified by Carbon.
- **Flash 3.8:** Handles fast file search and reference retrieval.

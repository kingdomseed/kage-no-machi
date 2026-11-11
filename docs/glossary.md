# Glossary

This reference defines the Edo architectural, botanical, topographic, atmospheric, musical, and `flutter_scene` rendering terms used across *Kage no Machi* and maps each term to plain English and its codebase location.

## Edo architecture, topography, flora, and street life

| Term | Plain-English meaning | Visual and gameplay role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| *Shukuba* | Post-town along an Edo highway | The riverside settlement ward that the player builds and illuminates | `ShukubaGraph` in `lib/shukuba/model/shukuba_types.dart` |
| *Kaidō* | Edo overland highway and town road | Smooth Catmull-Rom packed-earth thoroughfare with cart ruts, 3D *fuchi-ishi* stone border curbs, and worn shoulders that snaps nearby storefronts to face the street | `RoadStyle.kaidoRoad` (`Road` in `ShukubaHud`), `RoadSpline`, and `TerrainBuilder.buildRoadNode` |
| *Roji* & *Tobi-ishi* | Winding garden path and stepping stones | Narrow curved raked-gravel walkway studded with proud 3D slate stepping stones and pebble edging | `RoadStyle.gardenPath` (`Garden Path` in `ShukubaHud`) and `TerrainBuilder.buildRoadNode` |
| *Iwa* / *Iwakura* | Layered rock outcrop and garden boulder triad | Multi-phenotype sculpted slate-and-ochre crag, cliff shelf, or mossy three-stone *sanson-seki* garden arrangement | `StructureKind.rockOutcrop` (`Rock Outcrop`) and `EdoKitBuilder.buildRockOutcropNode` |
| *Ishigaki* & *Sangi-zumi* | Fitted dry-stone retaining wall and interlocking corner quoins | Battered polygonal castle-stone wall retaining a raised earth plateau, crowned with individual capstones and alternating long-short corner quoins | `TerraceCourse` (`Stone Terrace`), `ShukubaSurfaceRole.ishigakiStone`, and `TerrainBuilder.buildTerraceNode` |
| *Kaidan* / *Maruta-kaidan* | Stepped stone or timber-log staircase | Walkable cut-stone and log-riser steps flanked by stone cheek-walls wherever a road or path crosses a terrace rise | `TerrainBuilder.buildTerraceNode` and `TerrainBuilder.sampleGroundHeight` |
| *Shigarami* | Riverside timber piling and log revetment | Driven wooden bank stakes and horizontal retaining logs stabilizing river bends and bridge approaches | `TerrainBuilder.buildGorgeDressingNode` in `lib/shukuba/world/terrain_builder.dart` |
| *Machiya* | Wooden merchant townhouse | Narrow-frontage shop and residence with a ground-floor lattice storefront, *hisashi* porch eave, upper loft, and threshold street clutter | `StructureKind.machiya` (`Townhouse`) and `EdoKitBuilder.buildMachiyaNode` |
| *Chaya* | Roadside teahouse and rest inn | Pavilion with an open *engawa* timber veranda, vermilion cloth tea bench, stone lantern, steam wisp, and hanging lanterns | `StructureKind.chaya` (`Teahouse`) and `EdoKitBuilder.buildChayaNode` |
| *Kura* | Fireproof earthen-plaster storehouse | High-contrast chalk-white *shikkui* plaster merchant vault with dark dado trim, stepped gables, and *komodaru* cask racks | `StructureKind.kura` (`Storehouse`), `ShukubaSurfaceRole.kuraPlaster`, and `EdoKitBuilder.buildKuraNode` |
| *Yatai* | Open timber market stall | Small street vendor booth with a striped cloth awning, counter goods, barrels, steam wisp, and hanging lantern | `StructureKind.marketStall` (`Market Stall`) and `EdoKitBuilder.buildMarketStallNode` |
| *Hei* | Tiled courtyard wall | Continuous white-plaster and timber compound wall on a mossy stone plinth capped by a pitched *kawara* tile roof | `CourtyardWall` (`Courtyard Wall`) in `lib/shukuba/model/shukuba_types.dart` and `TerrainBuilder.buildWallNode` |
| *Torii* / Lantern gate | Vermilion highway archway | Framed cinnabar-lacquer gateway with *kasagi* top lintel and hanging lanterns that straddles lanes automatically | `StructureKind.toriiGate` (`Lantern Gate`, `straddlesRoad: true`) and `EdoKitBuilder.buildToriiGateNode` |
| *Komodaru* & *Daihachi-guruma* | Wrapped straw sake casks and two-wheeled wooden handcart | Stacked merchant barrel racks on timber skids, spoked cargo handcarts, and split firewood stacks tucked along building walls | `EdoKitBuilder.addSakeBarrelRack`, `addHandcart`, and `addFirewoodStack` |
| *Hisashi* & *Engawa* | Lower street-level porch roof and raised veranda | Projecting lean-to tile eave above shopfronts and exterior plank deck wrapping teahouses | `EdoKitBuilder.addLeanToRoof` and `EdoKitBuilder.buildChayaNode` |
| *Shōgi* | Vermilion-cloth roadside tea bench | Low wooden bench draped in red fabric outside teahouses for resting travelers | `EdoKitBuilder.buildChayaNode` (`ShukubaSurfaceRole.vermilionLacquer`) |
| *Kōshi* | Fine vertical wooden latticework | Timber grille across *machiya* windows that casts crisp vertical bars over warm interior *shōji* glow | `EdoKitBuilder.buildMachiyaNode` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Noren* & *Nobori* | Split cloth shop curtain and tall vertical shop banner | Gently breathing dyed fabric doorway panels and pole-hung two-tone shop banners framing lanes | `EdoKitBuilder.addNoboriBanner`, `buildMachiyaNode`, `buildChayaNode`, and `buildMarketStallNode` (`ShukubaSurfaceRole.fabricAwning`) |
| *Kawara* & *Onigawara* | Fired clay roof tiles and ridge-end finial tiles | Dark slate-indigo corrugated roof courses with cylindrical ribs, damp evening dew sheen, and sculpted ridge caps | `ShukubaSurfaceRole.kawaraTile` (`style_id = 1.0`) and `EdoKitBuilder.addGabledRoof` |
| *Gibōshi* | Ornamental bridge post cap | Lacquered collar-and-bud finial crowning main timber bridge railing posts | `TerrainBuilder.buildBridgeNode` in `lib/shukuba/world/terrain_builder.dart` |
| *Shitami-ita* & *Nuki* | Weatherboard cedar siding and timber tie-beams | Dark stained wood plank cladding and proud horizontal wall beams framing lower shop fronts and side gables | `ShukubaSurfaceRole.charredTimber` (`style_id = 2.0`) and `EdoKitBuilder.buildMachiyaNode` |
| *Chōchin*, *Shōji*, & *Tōrō* | Hanging paper lantern, paper screen, and carved stone lantern | Faceted amber street lanterns on catenary cords, glowing interior window screens, and mossy stone pedestal lanterns | `LanternSpan`, `EdoKitBuilder.addStoneToro`, and `assets/materials/shoji_lantern.fmat` |
| *Haori*, *Tamoto*, & *Oi* | Layered kimono jacket, hanging sleeve pouches, and peddler pack | Stylized Edo townsfolk silhouettes with draped *tamoto* sleeves, *obi* sashes, *sugegasa* hats, *oi* packs, and pole lanterns | `EdoKitBuilder.buildStreetAgentNode` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Momiji*, *Kuromatsu*, *Yanagi*, & *Take* | Autumn maple, black pine, weeping willow, and jointed bamboo | Per-tree DNA botanical builds with curved boughs, buttress roots, cloud-pruned pine shelves, trailing willow fronds, and arched bamboo culms | `EdoKitBuilder` tree builders and `assets/materials/foliage_canopy.fmat` |
| *Susuki*, *Nogiku*, *Higanbana*, & *Ashi* | Pampas plumes, wild daisies, red spider lilies, and bank reeds | Restrained habitat-pocket ground flora hugging stone walls, boulders, tree skirts, and river margins with calm ambient sway | `FloraScatterBuilder`, `ShukubaSurfaceRole.livingMeadow`, and `assets/materials/living_meadow.fmat` |
| *Kawagiri* & *Hotaru* | Rising river-gorge mist and evening fireflies | Depth-softened curl-noise mist ribbons above the stream, dusk pollen and falling leaves, and glowing night fireflies | `TimeOfDayRig` curves, `assets/materials/atmosphere_mist.fmat`, and `assets/materials/airborne_motes.fmat` |
| *Yagura* | Timber watchtower (parked) | Elevated lookout tower reserved for future watch and intrigue mechanics | Retained in `StructureKind.yaguraTower` for compatibility; omitted from starter ward and HUD |

## Musical and audio terms

| Term | Plain-English meaning | Role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| *Yo* scale | Bright daytime Japanese pentatonic scale (`D E G A B`) | Quantizes placement notes when `timeOfDay < 0.55` | `PentatonicScale.yo` in `lib/shukuba/model/shukuba_types.dart` |
| *In-sen* scale | Nocturnal Japanese pentatonic scale (`D Eb G A C`) | Quantizes placement notes when `timeOfDay >= 0.55` | `PentatonicScale.inSen` in `lib/shukuba/model/shukuba_types.dart` |
| *Koto* | Plucked 13-string zither | Plays plucked string notes when placing townhouses, teahouses, lantern gates, and maples | `EdoInstrument.koto` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Shakuhachi* | End-blown bamboo flute | Plays breathy flute notes when planting bamboo groves and weeping willows | `EdoInstrument.shakuhachi` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Hyōshigi* | Crisp wooden clappers | Plays rhythmic wood-block clicks for market stalls, roads, garden paths, courtyard walls, demolish, and undo | `EdoInstrument.hyoshigi` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Bonshō* | Deep bronze temple bell | Plays resonant low bell tones when raising stone terraces, *kura* storehouses, black pines, and rock outcrops | `EdoInstrument.bonsho` in `lib/shukuba/audio/edo_wav_synth.dart` |

## Rendering and engine terms

| Term | Plain-English meaning | Role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| `.fmat` | `flutter_scene` custom material source file | Compiled offline by `hook/build.dart` into SPIR-V and loaded via `loadFmatMaterial` | `assets/materials/*.fmat` and `hook/build.dart` |
| `alpha_to_coverage` | MSAA sub-pixel cutout coverage + shadow discard | Gives leaf sprays and habitat-pocket grass tufts soft cutout silhouettes, exact prepass normals, and perforated PCSS shadows | `assets/materials/foliage_canopy.fmat` and `assets/materials/living_meadow.fmat` |
| `InstancedMesh` | Single-draw GPU hardware instancing | Draws habitat-pocket grass tufts, *susuki* plumes, wildflowers, reeds, wall drapes, and airborne motes in batched GPU draws | `FloraScatterBuilder`, `AtmosphereBuilder`, and `assets/materials/living_meadow.fmat` |
| `dewFactor` | Time-of-day surface moisture curve | Modulates evening roughness on roof tiles, cobbles, and bridge planks to produce damp sky reflections | `TimeOfDayRig.dewFactor` in `lib/shukuba/model/shukuba_types.dart` and `assets/materials/gouache_lit.fmat` |
| `SumiInkPass` | Post-processing ink crease pass | Reads linear depth, octahedral normals, and surface roughness at `RenderStage.afterToneMapping` to draw brush-ink contours while sparing fine foliage | `lib/shukuba/look/sumi_ink_pass.dart` and `shaders/sumi_ink.frag` |
| `depthLayer` | Polygon-offset priority tier (`-8` to `8`) | Separates terrain (`-1`), structures, stone curbs, and flora (`0`), road overlays (`1`), build previews (`2`), and mist/motes (`3`..`4`) | `ShukubaSurfaceRole.depthLayer` in `lib/shukuba/model/shukuba_types.dart` |
| `ExploreTool` | Free-camera inspection mode | Default startup state (`NoBuildPreview`) with right-drag yaw/pitch orbit and left-drag pan | `ExploreTool` in `lib/shukuba/model/shukuba_types.dart`, `TacticalCameraRig`, and `ShukubaPage` |
| `BuildPreview` | Live 3D placement and brush marker | Shows snapped ground-footprint frames, doorway chevrons, preview lantern cords, Catmull-Rom drag ribbons, or demolish rings | `BuildPreview` in `lib/shukuba/model/shukuba_types.dart` and `assets/materials/ghost_preview.fmat` |
| `ShukubaFrameHarness` | Automated Metal capture and depth-probe runner | Settles frames, checks `findCoplanarOverlaps()` and `probeDepthConflicts()`, and saves PNG captures | `lib/shukuba/verify/frame_harness.dart` |

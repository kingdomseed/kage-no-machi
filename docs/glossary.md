# Glossary

This reference defines the Edo architectural, botanical, atmospheric, musical, and `flutter_scene` rendering terms used across *Kage no Machi* and maps each term to plain English and its codebase location.

## Edo architecture, flora, and street life

| Term | Plain-English meaning | Visual and gameplay role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| *Shukuba* | Post-town along an Edo highway | The riverside settlement ward that the player builds and illuminates | `ShukubaGraph` in `lib/shukuba/model/shukuba_types.dart` |
| *Kaidō* | Edo overland highway and lane | Stone-curbed gravel, cobble, and stepping-stone thoroughfare with worn dirt shoulders that snaps nearby storefronts to face the street | `RoadSpline` (`DrawLaneTool`) in `lib/shukuba/model/shukuba_types.dart` and `TerrainBuilder.buildRoadNode` |
| *Machiya* | Wooden merchant townhouse | Narrow-frontage shop and residence with a ground-floor lattice storefront, *hisashi* porch eave, and upper loft | `StructureKind.machiya` (`Townhouse`) and `EdoKitBuilder.buildMachiyaNode` |
| *Chaya* | Roadside teahouse and rest inn | Pavilion with an open *engawa* timber veranda, vermilion cloth tea bench, stone lantern, steam wisp, and hanging lanterns | `StructureKind.chaya` (`Teahouse`) and `EdoKitBuilder.buildChayaNode` |
| *Kura* | Fireproof earthen-plaster storehouse | High-contrast chalk-white *shikkui* plaster merchant vault with dark dado trim and thick stepped gables | `StructureKind.kura` (`Storehouse`), `ShukubaSurfaceRole.kuraPlaster`, and `EdoKitBuilder.buildKuraNode` |
| *Yatai* | Open timber market stall | Small street vendor booth with a striped cloth awning, counter goods, barrel, steam wisp, and hanging lantern | `StructureKind.marketStall` (`Market Stall`) and `EdoKitBuilder.buildMarketStallNode` |
| *Hei* | Tiled courtyard wall | Continuous white-plaster and timber compound wall on a mossy stone plinth capped by a pitched *kawara* tile roof | `CourtyardWall` (`BuildWallTool`) in `lib/shukuba/model/shukuba_types.dart` and `TerrainBuilder.buildWallNode` |
| *Torii* / Lantern gate | Vermilion highway archway | Framed cinnabar-lacquer gateway with *kasagi* top lintel and hanging lanterns that straddles lanes automatically | `StructureKind.toriiGate` (`Lantern Gate`, `straddlesRoad: true`) and `EdoKitBuilder.buildToriiGateNode` |
| *Hisashi* | Lower street-level porch roof | Projecting lean-to tile eave above a ground-floor shopfront below the main gable roof | `EdoKitBuilder.addLeanToRoof` on `machiya`, `chaya`, and `kura` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Engawa* | Raised wooden veranda | Exterior plank deck wrapping the front and side of a *chaya* teahouse under deep eaves | `EdoKitBuilder.buildChayaNode` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Shōgi* | Vermilion-cloth roadside tea bench | Low wooden bench draped in red fabric outside teahouses for resting travelers | `EdoKitBuilder.buildChayaNode` (`ShukubaSurfaceRole.vermilionLacquer`) |
| *Kōshi* | Fine vertical wooden latticework | Timber grille across *machiya* windows that casts crisp vertical bars over warm interior *shōji* glow | `EdoKitBuilder.buildMachiyaNode` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Noren* & *Nobori* | Split cloth shop curtain and tall vertical shop banner | Wind-fluttering dyed fabric doorway panels and tall pole-hung shop banners framing lively lanes | `EdoKitBuilder.buildMachiyaNode` and `buildChayaNode` (`ShukubaSurfaceRole.fabricAwning`) |
| *Kawara* | Fired clay roof tiles | Dark slate-indigo corrugated roof courses with 26 cm cylindrical ribs, 34 cm course steps, and damp evening dew sheen | `ShukubaSurfaceRole.kawaraTile` (`style_id = 1.0`) in `assets/materials/gouache_lit.fmat` |
| *Onigawara* | Ridge-end finial tile | Sculpted cap block terminating each end of a main roof ridge beam | `EdoKitBuilder.addGabledRoof` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Gibōshi* | Ornamental bridge post cap | Lacquered collar-and-bud finial crowning main timber bridge railing posts | `TerrainBuilder.buildBridgeNode` in `lib/shukuba/world/terrain_builder.dart` |
| *Shitami-ita* & *Nuki* | Weatherboard cedar siding and timber tie-beams | Dark stained wood plank cladding and proud horizontal wall beams framing lower shop fronts and side gables | `ShukubaSurfaceRole.charredTimber` (`style_id = 2.0`) in `assets/materials/gouache_lit.fmat` and `EdoKitBuilder.buildMachiyaNode` |
| *Ishigaki* | Fitted dry-stone masonry | Coursed polygonal granite-and-slate stonework forming raised terraces and plinths, paired with un-coursed fractured river boulders | `TerraceCourse` (`BuildTerraceTool`), `ShukubaSurfaceRole.ishigakiStone` (`style_id = 3.0`), and `TerrainBuilder` |
| *Chōchin* | Paper-and-bamboo hanging lantern | Plump faceted amber lantern hung along sagging catenary street cords and porch eaves with warm night haze halos | `LanternSpan`, `EdoKitBuilder.addLanternBody`, and `assets/materials/shoji_lantern.fmat` |
| *Shōji* | Translucent paper sliding screen | Timber-framed paper window panel that glows warm amber at dusk and night | `ShukubaSurfaceRole.shojiScreen` and `assets/materials/shoji_lantern.fmat` |
| *Andon* / *Tōrō* | Standing paper sign / stone garden lantern | Threshold shop lantern box (*andon*) and carved stone pedestal lantern (*tōrō*) | Threshold street props in `EdoKitBuilder.buildMachiyaNode` and `buildChayaNode` |
| *Haori* & *Sugegasa* | Layered kimono jacket and conical sedge hat | Expressive wide-sleeved Edo townsfolk attire paired with *obi* sashes, travel packs, and handheld lanterns | `EdoKitBuilder.buildStreetAgentNode` in `lib/shukuba/world/edo_kit_builder.dart` |
| *Momiji* | Autumn Japanese maple | Sinuous multi-branch maple with `alpha_to_coverage` lobed crimson and gold leaf sprays casting perforated ground shadows | `StructureKind.mapleCluster` (`Maple & Rocks`), `EdoKitBuilder.buildMapleNode`, and `assets/materials/foliage_canopy.fmat` |
| *Take* | Slender timber bamboo grove | Splayed olive-gold culms with feathered cutout lance-leaf sprays and fern undergrowth | `StructureKind.bambooGrove` (`Bamboo Grove`), `EdoKitBuilder.buildBambooNode`, and `assets/materials/foliage_canopy.fmat` |
| *Ashi* & *Kusa* | Riverside sedge reeds and wild grass | Wind-swaying 3D instanced grass tufts, golden bank reeds, mossy shrubs, and fallen maple leaves | `FloraScatterBuilder` (`InstancedMesh`) and `ShukubaSurfaceRole.groundMeadow` |
| *Kawagiri* & *Hotaru* | Rising river-gorge mist and evening fireflies | Depth-softened curl-noise mist ribbons above the stream, dusk pollen and falling leaves, and glowing night fireflies | `TimeOfDayRig` curves, `assets/materials/atmosphere_mist.fmat`, and `assets/materials/airborne_motes.fmat` |
| *Yagura* | Timber watchtower (parked) | Elevated lookout tower reserved for future watch and intrigue mechanics | Retained in `StructureKind.yaguraTower` for compatibility; omitted from starter ward and HUD |

## Musical and audio terms

| Term | Plain-English meaning | Role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| *Yo* scale | Bright daytime Japanese pentatonic scale (`D E G A B`) | Quantizes placement notes when `timeOfDay < 0.55` | `PentatonicScale.yo` in `lib/shukuba/model/shukuba_types.dart` |
| *In-sen* scale | Nocturnal Japanese pentatonic scale (`D Eb G A C`) | Quantizes placement notes when `timeOfDay >= 0.55` | `PentatonicScale.inSen` in `lib/shukuba/model/shukuba_types.dart` |
| *Koto* | Plucked 13-string zither | Plays plucked string notes when placing townhouses, teahouses, lantern gates, and maples | `EdoInstrument.koto` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Shakuhachi* | End-blown bamboo flute | Plays breathy flute notes when planting bamboo groves | `EdoInstrument.shakuhachi` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Hyōshigi* | Crisp wooden clappers | Plays rhythmic wood-block clicks for market stalls, cobble lanes, courtyard walls, demolish, and undo | `EdoInstrument.hyoshigi` in `lib/shukuba/audio/edo_wav_synth.dart` |
| *Bonshō* | Deep bronze temple bell | Plays resonant low bell tones when raising stone terraces and fireproof *kura* storehouses | `EdoInstrument.bonsho` in `lib/shukuba/audio/edo_wav_synth.dart` |

## Rendering and engine terms

| Term | Plain-English meaning | Role in *Kage no Machi* | Codebase mapping |
| :--- | :--- | :--- | :--- |
| `.fmat` | `flutter_scene` custom material source file | Compiled offline by `hook/build.dart` into SPIR-V and loaded via `loadFmatMaterial` | `assets/materials/*.fmat` and `hook/build.dart` |
| `alpha_to_coverage` | MSAA sub-pixel cutout coverage + shadow discard | Gives leaf sprays and grass tufts soft cutout silhouettes, exact prepass normals, and perforated PCSS shadows | `assets/materials/foliage_canopy.fmat` |
| `InstancedMesh` | Single-draw GPU hardware instancing | Draws thousands of wind-swaying grass tufts, reeds, fallen leaves, and airborne motes in one batch | `FloraScatterBuilder` and `AtmosphereBuilder` in `lib/shukuba/world/` |
| `dewFactor` | Time-of-day surface moisture curve | Modulates evening roughness on roof tiles, cobbles, and bridge planks to produce damp sky reflections | `TimeOfDayRig.dewFactor` in `lib/shukuba/model/shukuba_types.dart` and `assets/materials/gouache_lit.fmat` |
| `SumiInkPass` | Post-processing ink crease pass | Reads linear depth, octahedral normals, and surface roughness at `RenderStage.afterToneMapping` to draw brush-ink contours while sparing fine foliage | `lib/shukuba/look/sumi_ink_pass.dart` and `shaders/sumi_ink.frag` |
| `depthLayer` | Polygon-offset priority tier (`-8` to `8`) | Separates terrain (`-1`), structures and flora (`0`), lane overlays (`1`), build previews (`2`), and mist/motes (`3`..`4`) | `ShukubaSurfaceRole.depthLayer` in `lib/shukuba/model/shukuba_types.dart` |
| `ExploreTool` | Free-camera inspection mode | Default startup state (`NoBuildPreview`) so moving the cursor across the map shows zero placement markers until a dock card is clicked | `ExploreTool` in `lib/shukuba/model/shukuba_types.dart` and `ShukubaController` |
| `BuildPreview` | Live 3D placement and brush marker | Shows snapped ground-footprint frames with doorway chevrons and preview lantern cords, live drag ribbons, or demolish rings when a tool is active | `BuildPreview` in `lib/shukuba/model/shukuba_types.dart` and `assets/materials/ghost_preview.fmat` |
| `ShukubaFrameHarness` | Automated Metal capture and depth-probe runner | Settles frames, checks `findCoplanarOverlaps()` and `probeDepthConflicts()`, and saves PNG captures | `lib/shukuba/verify/frame_harness.dart` |

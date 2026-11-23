import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:kage_no_machi/shukuba/look/sumi_ink_pass.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

typedef LanternLightCluster = ({Vec3 centroid, int weight});

class EdoLookDriver implements ShukubaLookDriver {
  new({this.allowHeadlessFallback = false});

  static const int maxLanternPointLights = 12;
  static const double lanternClusterRadiusMeters = 5.5;
  static const double lanternPointLightRangeMeters = 8.2;
  static const double lanternPointLightFalloffExponent = 2;

  final bool allowHeadlessFallback;

  final Map<ShukubaSurfaceRole, Material> _materials = {};
  final List<DecalNode> _decalNodes = [];
  final List<PreprocessedMaterial> _decalMaterials = [];
  final List<Node> _lanternNodes = [];
  final List<PointLight> _lanternLights = [];
  final List<String> _loadedTexturePaths = [];

  Scene? _scene;
  SumiInkPass? _sumiPass;
  DirectionalLight? _keyLight;
  PhysicalSkySource? _skySource;
  SkyEnvironment? _skyEnvironment;
  EnvironmentSettings? _duskSettings;
  EnvironmentSettings? _nightSettings;

  double _lastSkyTimeValue = -1;
  int _attachEpoch = 0;

  DirectionalLight? get keyLight => _keyLight;

  PhysicalSkySource? get skySource => _skySource;

  List<PointLight> get activeLanternLights => List<PointLight>.unmodifiable([
    for (final light in _lanternLights)
      if (light.intensity > 0) light,
  ]);

  static Vec3 solarSkyDirectionFor(TimeOfDayRig rig) {
    final t = rig.value;
    final elevationDeg = 24 - (448 / 9) * t + (160 / 9) * t * t;
    final azimuthDeg = -58 - 28 * t;
    final elevation = elevationDeg * degrees2Radians;
    final azimuth = azimuthDeg * degrees2Radians;
    final horiz = math.cos(elevation);
    return Vec3(
      -math.sin(azimuth) * horiz,
      math.sin(elevation),
      -math.cos(azimuth) * horiz,
    ).normalized();
  }

  static List<LanternLightCluster> clusterLanternOrigins(
    List<Vec3> origins, {
    double mergeRadiusMeters = lanternClusterRadiusMeters,
    int maxClusters = maxLanternPointLights,
  }) {
    if (origins.isEmpty || maxClusters <= 0) {
      return const [];
    }
    final radiusSq = mergeRadiusMeters * mergeRadiusMeters;
    final clusters = <_MutableLanternCluster>[];

    for (var i = 0; i < origins.length; i++) {
      final origin = origins[i];
      var bestIdx = -1;
      var bestDistSq = radiusSq;
      for (var c = 0; c < clusters.length; c++) {
        final centroid = clusters[c].centroid;
        final dx = origin.x - centroid.x;
        final dy = origin.y - centroid.y;
        final dz = origin.z - centroid.z;
        final distSq = dx * dx + dy * dy + dz * dz;
        if (distSq <= bestDistSq) {
          bestDistSq = distSq;
          bestIdx = c;
        }
      }
      if (bestIdx >= 0) {
        clusters[bestIdx].add(origin);
      } else {
        clusters.add(_MutableLanternCluster(origin, i));
      }
    }

    clusters.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      if (byWeight != 0) {
        return byWeight;
      }
      return a.firstIndex.compareTo(b.firstIndex);
    });

    final count = math.min(maxClusters, clusters.length);
    return List<LanternLightCluster>.unmodifiable([
      for (var i = 0; i < count; i++)
        (centroid: clusters[i].centroid, weight: clusters[i].weight),
    ]);
  }

  @override
  Material materialFor(ShukubaSurfaceRole role) =>
      _materials[role] ?? defaultShukubaMaterial(role);

  /// Detaches scene-bound passes, decals, lights, and sky state without
  /// unloading reusable materials or textures.
  void detach() {
    _attachEpoch++;
    final scene = _scene;
    final pass = _sumiPass;
    if (scene != null && pass != null) {
      scene.removeRenderPass(pass);
    }
    _sumiPass = null;
    for (final node in _lanternNodes) {
      node.parent?.remove(node);
    }
    _lanternNodes.clear();
    for (final node in _decalNodes) {
      node.parent?.remove(node);
    }
    _decalNodes.clear();
    _decalMaterials.clear();
    _skySource = null;
    _skyEnvironment = null;
    _duskSettings = null;
    _nightSettings = null;
    _lastSkyTimeValue = -1;
    _scene = null;
  }

  @override
  Future<void> attach(Scene scene) async {
    detach();
    final epoch = ++_attachEpoch;
    _scene = scene;

    if (!allowHeadlessFallback) {
      await Scene.initializeStaticResources();
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
      if (_materials.length < ShukubaSurfaceRole.values.length) {
        await _loadProductionMaterials();
      }
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
      await _loadSumiInkPass(scene, epoch);
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
      await _loadDecalPool(scene, epoch);
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
    } else {
      try {
        await Scene.initializeStaticResources();
      } on Object catch (_) {}
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
      await _loadHeadlessFallback(scene, epoch);
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
    }

    _setupLightingAndSky(scene);
  }

  Future<void> _loadProductionMaterials() async {
    for (final role in ShukubaSurfaceRole.values) {
      final fmatPath = _fmatPathForRole(role);
      final mat = await loadFmatMaterial(fmatPath);
      mat.depthLayer = role.depthLayer;
      _configureRoleParameters(role, mat);
      await _bindRoleTextures(role, mat);
      _materials[role] = mat;
    }
  }

  Future<void> _bindRoleTextures(
    ShukubaSurfaceRole role,
    PreprocessedMaterial mat,
  ) async {
    switch (role) {
      case ShukubaSurfaceRole.kawaraTile:
        mat.parameters
          ..setFloat('texture_blend', 0.88)
          ..setFloat('texture_scale', 0.42)
          ..setFloat('normal_strength', 0.85);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/kawara_tile.png',
        );
        await _bindTexture(
          mat,
          'paint_albedo_b',
          'assets/textures/kayabuki_thatch.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/kawara_tile_normal.png',
        );
        await _bindTexture(
          mat,
          'paint_normal_b',
          'assets/textures/kayabuki_thatch_normal.png',
        );
      case ShukubaSurfaceRole.ishigakiStone:
      case ShukubaSurfaceRole.steppingStone:
        mat.parameters
          ..setFloat('texture_blend', 0.86)
          ..setFloat('texture_scale', 0.34)
          ..setFloat('normal_strength', 0.95);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/castle_ishigaki.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/castle_ishigaki_normal.png',
        );
      case ShukubaSurfaceRole.packedEarth:
        mat.parameters
          ..setFloat('texture_blend', 0.88)
          ..setFloat('texture_scale', 0.14)
          ..setFloat('normal_strength', 0.72);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/meadow_moss.png',
        );
        await _bindTexture(
          mat,
          'paint_albedo_b',
          'assets/textures/kaido_earth.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/meadow_moss_normal.png',
        );
        await _bindTexture(
          mat,
          'paint_normal_b',
          'assets/textures/kaido_earth_normal.png',
        );
      case ShukubaSurfaceRole.laneOverlay:
        mat.parameters
          ..setFloat('texture_blend', 0.84)
          ..setFloat('texture_scale', 0.34)
          ..setFloat('normal_strength', 0.92);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/cobblestone_edo.png',
        );
        await _bindTexture(
          mat,
          'paint_albedo_b',
          'assets/textures/meadow_moss.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/cobblestone_edo_normal.png',
        );
        await _bindTexture(
          mat,
          'paint_normal_b',
          'assets/textures/meadow_moss_normal.png',
        );
      case ShukubaSurfaceRole.charredTimber:
        mat.parameters
          ..setFloat('texture_blend', 0.88)
          ..setFloat('texture_scale', 0.48)
          ..setFloat('normal_strength', 0.72);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/cedar_timber.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/cedar_timber_normal.png',
        );
      case ShukubaSurfaceRole.plasterWall:
      case ShukubaSurfaceRole.kuraPlaster:
        mat.parameters
          ..setFloat('texture_blend', 0.84)
          ..setFloat('texture_scale', 0.32)
          ..setFloat('normal_strength', 0.45);
        await _bindTexture(
          mat,
          'paint_albedo',
          'assets/textures/shikkui_plaster.png',
        );
        await _bindTexture(
          mat,
          'paint_normal',
          'assets/textures/shikkui_plaster_normal.png',
        );
      case ShukubaSurfaceRole.mountainVista:
        mat.parameters.setFloat('texture_scale', 1);
        await _bindTexture(
          mat,
          'mountain_albedo',
          'assets/textures/mountain_forest.png',
        );
        await _bindTexture(
          mat,
          'mountain_normal',
          'assets/textures/mountain_forest_normal.png',
        );
      case ShukubaSurfaceRole.paintedClouds:
        await _bindTexture(
          mat,
          'cloud_pano',
          'assets/textures/sky_edo_dusk.png',
        );
      case ShukubaSurfaceRole.mapleCanopy:
        mat.parameters.setFloat('foliage_tex_blend', 1);
        await _bindTexture(
          mat,
          'foliage_atlas',
          'assets/textures/foliage_maple.png',
        );
      case ShukubaSurfaceRole.bambooCanopy:
        mat.parameters.setFloat('foliage_tex_blend', 1);
        await _bindTexture(
          mat,
          'foliage_atlas',
          'assets/textures/foliage_bamboo.png',
        );
      case ShukubaSurfaceRole.pineCanopy:
        mat.parameters.setFloat('foliage_tex_blend', 1);
        await _bindTexture(
          mat,
          'foliage_atlas',
          'assets/textures/foliage_pine.png',
        );
      case ShukubaSurfaceRole.willowCanopy:
        mat.parameters.setFloat('foliage_tex_blend', 1);
        await _bindTexture(
          mat,
          'foliage_atlas',
          'assets/textures/foliage_willow.png',
        );
      case ShukubaSurfaceRole.fabricAwning:
      case ShukubaSurfaceRole.vermilionLacquer:
      case ShukubaSurfaceRole.shojiScreen:
      case ShukubaSurfaceRole.chochinLantern:
      case ShukubaSurfaceRole.groundMeadow:
      case ShukubaSurfaceRole.livingMeadow:
      case ShukubaSurfaceRole.riverWater:
      case ShukubaSurfaceRole.harborWater:
      case ShukubaSurfaceRole.ghostPreview:
      case ShukubaSurfaceRole.riverMist:
      case ShukubaSurfaceRole.lanternHaze:
      case ShukubaSurfaceRole.airborneMotes:
        break;
    }
  }

  Future<void> _bindTexture(
    PreprocessedMaterial mat,
    String paramName,
    String assetPath,
  ) async {
    try {
      final texSource = await loadTexture(assetPath);
      _loadedTexturePaths.add(assetPath);
      final gpuTex = texSource.sampledTexture;
      if (gpuTex != null) {
        mat.parameters.setTexture(
          paramName,
          gpuTex,
          sampler: texSource.sampledSampler,
        );
      }
    } on Object catch (_) {
      if (!allowHeadlessFallback) {
        rethrow;
      }
    }
  }

  Future<void> _loadSumiInkPass(Scene scene, int epoch) async {
    final key = await gpu.resolveShaderBundleKey('sumi_ink');
    final library = await gpu.loadShaderLibraryAsync(key);
    if (_attachEpoch != epoch || !identical(_scene, scene)) {
      return;
    }
    final shader = library?['SumiInkFragment'];
    if (shader != null) {
      final pass = SumiInkPass(shader);
      _sumiPass = pass;
      scene.addRenderPass(pass);
    }
  }

  Future<void> _loadDecalPool(Scene scene, int epoch) async {
    for (var i = 0; i < 12; i++) {
      final mat = await loadFmatMaterial(
        'assets/materials/sightcone_decal.fmat',
      );
      if (_attachEpoch != epoch || !identical(_scene, scene)) {
        return;
      }
      _decalMaterials.add(mat);
      final decal = DecalNode(material: mat, name: 'sightcone_decal_$i')
        ..visible = false;
      _decalNodes.add(decal);
      scene.root.add(decal);
    }
  }

  Future<void> _loadHeadlessFallback(Scene scene, int epoch) async {
    if (_materials.length < ShukubaSurfaceRole.values.length) {
      try {
        await _loadProductionMaterials();
      } on Object catch (_) {
        for (final role in ShukubaSurfaceRole.values) {
          _materials[role] = defaultShukubaMaterial(role);
        }
      }
    }
    if (_attachEpoch != epoch || !identical(_scene, scene)) {
      return;
    }

    try {
      await _loadSumiInkPass(scene, epoch);
    } on Object catch (_) {}
    if (_attachEpoch != epoch || !identical(_scene, scene)) {
      return;
    }

    try {
      await _loadDecalPool(scene, epoch);
    } on Object catch (_) {}
  }

  void _ensureLightPool() {
    _keyLight ??= DirectionalLight(
      castsShadow: true,
      priority: 10,
      angularRadius: 0.052,
      shadowSoftness: 0.28,
      shadowMaxDistance: 145,
      shadowCascadeSplitLambda: 0.65,
      cascadeOverlap: 0.08,
      shadowMapResolution: 2048,
      shadowFilter: DirectionalShadowFilter.pcss,
      shadowAmbientStrength: 0.28,
      // Keep contact shadows disabled (default false): fp16 linear_depth ULP at
      // 100-250 m stripes distant hills/mountains; 4-cascade 2048px PCSS +
      // bent-cone GTAO handles grounding.
      contactShadowDistance: 0.45,
    )..shadowCascadeCount = 4;

    if (_lanternLights.isEmpty) {
      for (var i = 0; i < maxLanternPointLights; i++) {
        _lanternLights.add(
          PointLight(
            color: Vector3(1, 0.56, 0.20),
            intensity: 0,
            range: lanternPointLightRangeMeters,
          )..falloffExponent = lanternPointLightFalloffExponent,
        );
      }
    }
  }

  void _setupLightingAndSky(Scene scene) {
    _ensureLightPool();
    scene.directionalLight = _keyLight;

    for (final node in _lanternNodes) {
      node.parent?.remove(node);
    }
    _lanternNodes.clear();
    for (var i = 0; i < _lanternLights.length; i++) {
      final node = Node(name: 'lantern_light_$i')
        ..addComponent(PointLightComponent(_lanternLights[i]))
        ..visible = false;
      _lanternNodes.add(node);
      scene.root.add(node);
    }

    Skybox? skyboxInstance;
    SkyEnvironment? skyEnvInstance;
    try {
      final sky = PhysicalSkySource();
      _applySkyForRig(sky, TimeOfDayRig.goldenDusk);
      _skySource = sky;
      skyboxInstance = Skybox(sky);
      skyEnvInstance = SkyEnvironment(sky);
      _skyEnvironment = skyEnvInstance;

      scene
        ..skybox = skyboxInstance
        ..skyEnvironment = skyEnvInstance
        ..antiAliasingMode = AntiAliasingMode.msaa;
    } on Object catch (_) {
      if (!allowHeadlessFallback) rethrow;
    }

    final dusk = EnvironmentSettings(
      skybox: skyboxInstance,
      skyEnvironment: skyEnvInstance,
      toneMapping: ToneMappingMode.aces,
      environmentIntensity: 2.55,
      exposure: 1.02,
      colorGradingEnabled: true,
      saturation: 1.12,
      contrast: 1.08,
      temperature: 0.18,
      lift: Vector3(0.010, 0.018, 0.038),
      bloomEnabled: true,
      bloomThreshold: 1.15,
      bloomIntensity: 0.16,
      bloomScatter: 0.56,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      ambientOcclusionIntensity: 1.15,
      ambientOcclusionRadius: 1.25,
      ambientOcclusionPower: 1.48,
      ambientOcclusionMultiBounce: 0.62,
      ambientOcclusionDirectLightAffect: 0.08,
      screenSpaceReflectionsEnabled: true,
      screenSpaceReflectionsIntensity: 0.72,
      screenSpaceReflectionsMaxDistance: 44,
      screenSpaceReflectionsResolutionScale: 0.5,
      fogEnabled: true,
      fogColor: Vector3(0.34, 0.27, 0.36),
      fogStart: 22,
      fogDensity: 0.0018,
      fogMaxOpacity: 0.24,
      fogSunInScatter: 0.06,
      fogSunInScatterExponent: 10,
      fogSkyColorInfluence: 0.28,
      fogHeight: 1.4,
      fogHeightFalloff: 0.44,
      godRaysEnabled: true,
      godRaysIntensity: 0.34,
      godRaysAnisotropy: 0.66,
      godRaysStepCount: 64,
      godRaysMaxDistance: 54,
      godRaysColor: Vector3(1, 0.66, 0.28),
      vignetteEnabled: true,
      vignetteIntensity: 0.18,
    )..fogMode = FogMode.exponential;

    final night = EnvironmentSettings(
      skybox: skyboxInstance,
      skyEnvironment: skyEnvInstance,
      toneMapping: ToneMappingMode.aces,
      environmentIntensity: 1.45,
      exposure: 0.98,
      colorGradingEnabled: true,
      saturation: 1.18,
      contrast: 1.06,
      temperature: -0.06,
      lift: Vector3(0.018, 0.034, 0.068),
      bloomEnabled: true,
      bloomThreshold: 0.95,
      bloomIntensity: 0.24,
      bloomScatter: 0.65,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      ambientOcclusionIntensity: 1.15,
      ambientOcclusionRadius: 1.25,
      ambientOcclusionPower: 1.48,
      ambientOcclusionMultiBounce: 0.62,
      ambientOcclusionDirectLightAffect: 0.08,
      screenSpaceReflectionsEnabled: true,
      screenSpaceReflectionsIntensity: 0.85,
      screenSpaceReflectionsMaxDistance: 44,
      screenSpaceReflectionsResolutionScale: 0.5,
      fogEnabled: true,
      fogColor: Vector3(0.055, 0.11, 0.21),
      fogStart: 22,
      fogDensity: 0.0048,
      fogMaxOpacity: 0.44,
      fogSunInScatter: 0.04,
      fogSunInScatterExponent: 10,
      fogSkyColorInfluence: 0.26,
      fogHeight: 1.4,
      fogHeightFalloff: 0.34,
      godRaysEnabled: true,
      godRaysIntensity: 0.08,
      godRaysDensity: 0.26,
      godRaysAnisotropy: 0.66,
      godRaysStepCount: 64,
      godRaysMaxDistance: 54,
      godRaysColor: Vector3(0.46, 0.66, 0.96),
      vignetteEnabled: true,
      vignetteIntensity: 0.28,
    )..fogMode = FogMode.exponential;

    _duskSettings = dusk;
    _nightSettings = night;
    scene.environmentSettings = dusk;
  }

  @override
  void syncFrame({
    required TimeOfDayRig rig,
    required MagistrateVisionState vision,
    required List<WatchSightcone> sightcones,
    required List<Vec3> lanternOrigins,
    required double elapsedSeconds,
  }) {
    _ensureLightPool();

    final key = _keyLight;
    if (key != null) {
      key
        ..direction = rig.celestialRayDirection.toVector3()
        ..color = rig.celestialLinearRgb.toVector3()
        ..intensity = rig.celestialIntensity
        ..shadowAmbientStrength = 0.28 + 0.08 * rig.nightFactor;
    }

    final clusteredLanterns = clusterLanternOrigins(lanternOrigins);
    final baseLanternIntensity = rig.lanternPointLightIntensity;
    for (var i = 0; i < _lanternLights.length; i++) {
      if (i < clusteredLanterns.length) {
        final cluster = clusteredLanterns[i];
        final weightBoost = 1 + 0.16 * math.min(cluster.weight - 1, 4);
        _lanternLights[i]
          ..intensity = baseLanternIntensity * 0.68 * weightBoost
          ..range = lanternPointLightRangeMeters
          ..falloffExponent = lanternPointLightFalloffExponent;
        if (i < _lanternNodes.length) {
          _lanternNodes[i]
            ..position = cluster.centroid.toVector3()
            ..visible = true;
        }
      } else {
        _lanternLights[i].intensity = 0;
        if (i < _lanternNodes.length) {
          _lanternNodes[i].visible = false;
        }
      }
    }

    final scene = _scene;
    if (scene == null) return;

    final dusk = _duskSettings;
    final night = _nightSettings;
    if (dusk != null && night != null) {
      scene.environmentSettings = EnvironmentSettings.lerp(
        dusk,
        night,
        rig.nightFactor,
      );
    }

    if ((_lastSkyTimeValue - rig.value).abs() > 0.002) {
      _lastSkyTimeValue = rig.value;
      final sky = _skySource;
      if (sky != null) {
        _applySkyForRig(sky, rig);
        _skyEnvironment?.invalidate();
      }
    }

    _setParamFloat(
      ShukubaSurfaceRole.shojiScreen,
      'emissive_gain',
      rig.shojiEmissiveGain,
    );
    _setParamFloat(ShukubaSurfaceRole.shojiScreen, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.chochinLantern,
      'emissive_gain',
      rig.lanternEmissiveGain,
    );
    _setParamFloat(
      ShukubaSurfaceRole.chochinLantern,
      'time_sec',
      elapsedSeconds,
    );
    final sunTranslucency = 1.0 - rig.nightFactor * 0.90;
    final gust = rig.windGustStrength;
    _setParamFloat(ShukubaSurfaceRole.mapleCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.mapleCanopy,
      'sun_translucency',
      sunTranslucency,
    );
    _setParamFloat(
      ShukubaSurfaceRole.mapleCanopy,
      'wind_strength',
      0.16 * gust,
    );
    _setParamFloat(ShukubaSurfaceRole.bambooCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.bambooCanopy,
      'sun_translucency',
      sunTranslucency,
    );
    _setParamFloat(
      ShukubaSurfaceRole.bambooCanopy,
      'wind_strength',
      0.22 * gust,
    );
    _setParamFloat(ShukubaSurfaceRole.pineCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.pineCanopy,
      'sun_translucency',
      sunTranslucency * 0.65,
    );
    _setParamFloat(ShukubaSurfaceRole.pineCanopy, 'wind_strength', 0.14 * gust);
    _setParamFloat(ShukubaSurfaceRole.willowCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.willowCanopy,
      'sun_translucency',
      sunTranslucency,
    );
    _setParamFloat(
      ShukubaSurfaceRole.willowCanopy,
      'wind_strength',
      0.30 * gust,
    );
    _setParamFloat(ShukubaSurfaceRole.groundMeadow, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.groundMeadow,
      'sun_translucency',
      sunTranslucency,
    );
    _setParamFloat(
      ShukubaSurfaceRole.groundMeadow,
      'wind_strength',
      0.24 * gust,
    );
    _setParamFloat(ShukubaSurfaceRole.livingMeadow, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.livingMeadow,
      'sun_translucency',
      rig.meadowTranslucency,
    );
    _setParamFloat(ShukubaSurfaceRole.livingMeadow, 'gust_strength', gust);
    _setParamFloat(ShukubaSurfaceRole.livingMeadow, 'dew_sheen', rig.dewFactor);
    _setParamFloat(ShukubaSurfaceRole.riverWater, 'gust_strength', gust);
    _setParamFloat(ShukubaSurfaceRole.riverWater, 'time_sec', elapsedSeconds);
    _setParamFloat(ShukubaSurfaceRole.harborWater, 'gust_strength', gust);
    _setParamFloat(ShukubaSurfaceRole.harborWater, 'time_sec', elapsedSeconds);
    _setParamFloat(
      ShukubaSurfaceRole.harborWater,
      'night_mix',
      rig.nightFactor,
    );
    _setParamFloat(ShukubaSurfaceRole.ghostPreview, 'time_sec', elapsedSeconds);

    const gouacheRoles = [
      ShukubaSurfaceRole.packedEarth,
      ShukubaSurfaceRole.ishigakiStone,
      ShukubaSurfaceRole.steppingStone,
      ShukubaSurfaceRole.laneOverlay,
      ShukubaSurfaceRole.plasterWall,
      ShukubaSurfaceRole.kuraPlaster,
      ShukubaSurfaceRole.charredTimber,
      ShukubaSurfaceRole.kawaraTile,
      ShukubaSurfaceRole.fabricAwning,
      ShukubaSurfaceRole.vermilionLacquer,
    ];
    for (final role in gouacheRoles) {
      _setParamFloat(role, 'dew_sheen', rig.dewFactor);
    }
    _setParamFloat(ShukubaSurfaceRole.fabricAwning, 'gust_strength', gust);
    _setParamFloat(ShukubaSurfaceRole.fabricAwning, 'time_sec', elapsedSeconds);

    _setParamFloat(
      ShukubaSurfaceRole.riverMist,
      'mist_opacity',
      rig.riverMistOpacity,
    );
    _setParamFloat(ShukubaSurfaceRole.riverMist, 'night_mix', rig.nightFactor);
    _setParamFloat(ShukubaSurfaceRole.riverMist, 'time_sec', elapsedSeconds);

    _setParamFloat(
      ShukubaSurfaceRole.lanternHaze,
      'mist_opacity',
      rig.lanternHaloOpacity,
    );
    _setParamFloat(
      ShukubaSurfaceRole.lanternHaze,
      'night_mix',
      rig.nightFactor,
    );
    _setParamFloat(ShukubaSurfaceRole.lanternHaze, 'time_sec', elapsedSeconds);

    _setParamFloat(
      ShukubaSurfaceRole.airborneMotes,
      'dusk_gain',
      rig.duskMoteGain,
    );
    _setParamFloat(
      ShukubaSurfaceRole.airborneMotes,
      'night_gain',
      rig.nightFireflyGain,
    );
    _setParamFloat(ShukubaSurfaceRole.airborneMotes, 'gust_strength', gust);
    _setParamFloat(
      ShukubaSurfaceRole.airborneMotes,
      'time_sec',
      elapsedSeconds,
    );
    _setParamFloat(
      ShukubaSurfaceRole.mountainVista,
      'night_mix',
      rig.nightFactor,
    );
    _setParamFloat(
      ShukubaSurfaceRole.paintedClouds,
      'night_mix',
      rig.nightFactor,
    );
    _setParamFloat(
      ShukubaSurfaceRole.paintedClouds,
      'time_sec',
      elapsedSeconds,
    );

    for (var i = 0; i < _decalNodes.length; i++) {
      if (i < sightcones.length) {
        final cone = sightcones[i];
        final opacity = vision.decalOpacity(isWatchtower: cone.isWatchtower);
        if (opacity <= 0.001) {
          _decalNodes[i]
            ..visible = false
            ..fade = 0;
        } else {
          _decalNodes[i]
            ..visible = true
            ..fade = opacity;
          if (i < _decalMaterials.length) {
            _decalMaterials[i].parameters
              ..setFloat('decal_fade', opacity)
              ..setFloat('half_angle_rad', cone.halfAngleRadians)
              ..setFloat('cone_range_norm', cone.coneRangeNormalized)
              ..setFloat('alert_mix', cone.alertLevel)
              ..setFloat('time_sec', elapsedSeconds);
          }
          _decalNodes[i].project(
            point: cone.decalProjectionCenter.toVector3(),
            normal: Vector3(0, 1, 0),
            size: cone.decalBoxSize,
            depth: 8,
            rotation: cone.yawRadians,
          );
        }
      } else {
        _decalNodes[i]
          ..visible = false
          ..fade = 0;
      }
    }
  }

  void _setParamFloat(ShukubaSurfaceRole role, String param, double value) {
    final mat = _materials[role];
    if (mat is PreprocessedMaterial) {
      mat.parameters.setFloat(param, value);
    }
  }

  @override
  void dispose() {
    detach();
    _lanternLights.clear();
    for (final path in _loadedTexturePaths) {
      try {
        unawaited(releaseTexture(path).then((_) {}, onError: (_) {}));
      } on Object catch (_) {}
    }
    _loadedTexturePaths.clear();
    _materials.clear();
    _keyLight = null;
  }

  static void _applySkyForRig(PhysicalSkySource sky, TimeOfDayRig rig) {
    sky.sunDirection = rig.celestialSkyDirection.toVector3();
    if (!rig.isMoonlit) {
      final duskProgress = (rig.value / TimeOfDayRig.scaleSwitchScalar).clamp(
        0.0,
        1.0,
      );
      sky
        ..sunAngularRadius = 0.032
        ..turbidity = 3.8 - 0.5 * duskProgress
        ..rayleighCoefficient = 1.95
        ..mieCoefficient = 0.0040 * (1 - 0.20 * duskProgress)
        ..mieEccentricity = 0.78
        ..energy = 0.24 - 0.07 * duskProgress
        ..rayleighColor = Vector3(0.14, 0.28, 0.78)
        ..mieColor = Vector3(
          1,
          0.48 - 0.08 * duskProgress,
          0.18 - 0.05 * duskProgress,
        )
        ..groundColor = Vector3(
          0.26 * (1 - 0.35 * duskProgress),
          0.20 * (1 - 0.35 * duskProgress),
          0.22 * (1 - 0.35 * duskProgress),
        );
      return;
    }
    sky
      ..sunAngularRadius = 0.014
      ..turbidity = 3.4
      ..rayleighCoefficient = 2.2
      ..mieCoefficient = 0.0035
      ..mieEccentricity = 0.86
      ..energy = 0.105
      ..rayleighColor = Vector3(0.12, 0.30, 0.80)
      ..mieColor = Vector3(0.46, 0.66, 0.96)
      ..groundColor = Vector3(0.045, 0.070, 0.135);
  }

  static String _fmatPathForRole(ShukubaSurfaceRole role) => switch (role) {
    ShukubaSurfaceRole.packedEarth ||
    ShukubaSurfaceRole.ishigakiStone ||
    ShukubaSurfaceRole.steppingStone ||
    ShukubaSurfaceRole.laneOverlay ||
    ShukubaSurfaceRole.plasterWall ||
    ShukubaSurfaceRole.kuraPlaster ||
    ShukubaSurfaceRole.charredTimber ||
    ShukubaSurfaceRole.kawaraTile ||
    ShukubaSurfaceRole.fabricAwning ||
    ShukubaSurfaceRole.vermilionLacquer => 'assets/materials/gouache_lit.fmat',
    ShukubaSurfaceRole.shojiScreen ||
    ShukubaSurfaceRole.chochinLantern => 'assets/materials/shoji_lantern.fmat',
    ShukubaSurfaceRole.mapleCanopy ||
    ShukubaSurfaceRole.bambooCanopy ||
    ShukubaSurfaceRole.pineCanopy ||
    ShukubaSurfaceRole.willowCanopy ||
    ShukubaSurfaceRole.groundMeadow => 'assets/materials/foliage_canopy.fmat',
    ShukubaSurfaceRole.livingMeadow => 'assets/materials/living_meadow.fmat',
    ShukubaSurfaceRole.riverWater => 'assets/materials/river_water.fmat',
    ShukubaSurfaceRole.harborWater => 'assets/materials/harbor_water.fmat',
    ShukubaSurfaceRole.ghostPreview => 'assets/materials/ghost_preview.fmat',
    ShukubaSurfaceRole.riverMist ||
    ShukubaSurfaceRole.lanternHaze => 'assets/materials/atmosphere_mist.fmat',
    ShukubaSurfaceRole.airborneMotes => 'assets/materials/airborne_motes.fmat',
    ShukubaSurfaceRole.mountainVista => 'assets/materials/mountain_vista.fmat',
    ShukubaSurfaceRole.paintedClouds => 'assets/materials/painted_clouds.fmat',
  };

  static void _configureRoleParameters(
    ShukubaSurfaceRole role,
    PreprocessedMaterial mat,
  ) {
    switch (role) {
      case ShukubaSurfaceRole.packedEarth:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.18, 0.155, 0.092, 1))
          ..setVec4('warm_tint', Vector4(0.32, 0.25, 0.145, 1))
          ..setFloat('roughness_val', 0.92)
          ..setFloat('grain_scale', 5.2)
          ..setFloat('weathering', 0.20)
          ..setFloat('style_id', 5);
      case ShukubaSurfaceRole.ishigakiStone:
      case ShukubaSurfaceRole.steppingStone:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.26, 0.24, 0.21, 1))
          ..setVec4('warm_tint', Vector4(0.38, 0.34, 0.28, 1))
          ..setFloat('roughness_val', 0.82)
          ..setFloat('grain_scale', 9.5)
          ..setFloat('weathering', 0.34)
          ..setFloat('style_id', 3);
      case ShukubaSurfaceRole.laneOverlay:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.36, 0.27, 0.16, 1))
          ..setVec4('warm_tint', Vector4(0.50, 0.38, 0.22, 1))
          ..setFloat('roughness_val', 0.88)
          ..setFloat('grain_scale', 6.4)
          ..setFloat('weathering', 0.16)
          ..setFloat('style_id', 5.5);
      case ShukubaSurfaceRole.plasterWall:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.56, 0.47, 0.36, 1))
          ..setVec4('warm_tint', Vector4(0.72, 0.60, 0.45, 1))
          ..setFloat('roughness_val', 0.85)
          ..setFloat('grain_scale', 11)
          ..setFloat('weathering', 0.28)
          ..setFloat('style_id', 4);
      case ShukubaSurfaceRole.kuraPlaster:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.78, 0.74, 0.66, 1))
          ..setVec4('warm_tint', Vector4(0.90, 0.85, 0.76, 1))
          ..setFloat('roughness_val', 0.82)
          ..setFloat('grain_scale', 10)
          ..setFloat('weathering', 0.20)
          ..setFloat('style_id', 4);
      case ShukubaSurfaceRole.charredTimber:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.115, 0.072, 0.040, 1))
          ..setVec4('warm_tint', Vector4(0.195, 0.122, 0.068, 1))
          ..setFloat('roughness_val', 0.74)
          ..setFloat('grain_scale', 14)
          ..setFloat('weathering', 0.22)
          ..setFloat('style_id', 2);
      case ShukubaSurfaceRole.kawaraTile:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.068, 0.095, 0.145, 1))
          ..setVec4('warm_tint', Vector4(0.115, 0.148, 0.205, 1))
          ..setFloat('roughness_val', 0.42)
          ..setFloat('grain_scale', 12)
          ..setFloat('weathering', 0.24)
          ..setFloat('style_id', 1);
      case ShukubaSurfaceRole.fabricAwning:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.36, 0.055, 0.025, 1))
          ..setVec4('warm_tint', Vector4(0.56, 0.12, 0.042, 1))
          ..setFloat('roughness_val', 0.84)
          ..setFloat('grain_scale', 16)
          ..setFloat('weathering', 0.16)
          ..setFloat('style_id', 6);
      case ShukubaSurfaceRole.vermilionLacquer:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.52, 0.062, 0.028, 1))
          ..setVec4('warm_tint', Vector4(0.72, 0.115, 0.042, 1))
          ..setFloat('roughness_val', 0.42)
          ..setFloat('grain_scale', 14)
          ..setFloat('weathering', 0.12)
          ..setFloat('style_id', 6.5);
      case ShukubaSurfaceRole.shojiScreen:
        mat.parameters
          ..setVec4('paper_color', Vector4(0.88, 0.72, 0.46, 1))
          ..setVec4('glow_color', Vector4(1, 0.60, 0.19, 1))
          ..setFloat('emissive_gain', 0.42)
          ..setFloat('rib_freq', 7);
      case ShukubaSurfaceRole.chochinLantern:
        mat.parameters
          ..setVec4('paper_color', Vector4(0.96, 0.48, 0.16, 1))
          ..setVec4('glow_color', Vector4(1, 0.44, 0.10, 1))
          ..setFloat('emissive_gain', 1.15)
          ..setFloat('rib_freq', 12);
      case ShukubaSurfaceRole.mapleCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.34, 0.16, 0.085, 1))
          ..setVec4('leaf_secondary', Vector4(0.98, 0.84, 0.50, 1))
          ..setFloat('rim_warmth', 0.64)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.16)
          ..setFloat('foliage_kind', 0);
      case ShukubaSurfaceRole.bambooCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.058, 0.138, 0.046, 1))
          ..setVec4('leaf_secondary', Vector4(0.145, 0.235, 0.078, 1))
          ..setFloat('rim_warmth', 0.46)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.22)
          ..setFloat('foliage_kind', 1);
      case ShukubaSurfaceRole.pineCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.032, 0.088, 0.056, 1))
          ..setVec4('leaf_secondary', Vector4(0.118, 0.255, 0.090, 1))
          ..setFloat('rim_warmth', 0.34)
          ..setFloat('sun_translucency', 0.72)
          ..setFloat('wind_strength', 0.14)
          ..setFloat('foliage_kind', 3);
      case ShukubaSurfaceRole.willowCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.064, 0.148, 0.056, 1))
          ..setVec4('leaf_secondary', Vector4(0.165, 0.245, 0.092, 1))
          ..setFloat('rim_warmth', 0.48)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.30)
          ..setFloat('foliage_kind', 4);
      case ShukubaSurfaceRole.groundMeadow:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.048, 0.105, 0.044, 1))
          ..setVec4('leaf_secondary', Vector4(0.145, 0.235, 0.085, 1))
          ..setFloat('rim_warmth', 0.18)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.24)
          ..setFloat('foliage_kind', 2);
      case ShukubaSurfaceRole.livingMeadow:
        mat.parameters
          ..setFloat('sun_translucency', 1)
          ..setFloat('gust_strength', 1)
          ..setFloat('dew_sheen', 0.22)
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.riverWater:
        mat.parameters
          ..setVec4('shallow_color', Vector4(0.11, 0.34, 0.31, 0.82))
          ..setVec4('deep_color', Vector4(0.024, 0.115, 0.145, 0.96))
          ..setVec4('foam_color', Vector4(0.90, 0.91, 0.86, 0.78))
          ..setFloat('flow_speed', 0.95);
      case ShukubaSurfaceRole.harborWater:
        mat.parameters
          ..setVec4('shallow_color', Vector4(0.026, 0.088, 0.118, 0.88))
          ..setVec4('deep_color', Vector4(0.008, 0.022, 0.052, 0.98))
          ..setVec4('foam_color', Vector4(0.92, 0.88, 0.82, 0.92))
          ..setFloat('gust_strength', 1)
          ..setFloat('time_sec', 0)
          ..setFloat('night_mix', 0);
      case ShukubaSurfaceRole.ghostPreview:
        mat.parameters
          ..setVec4('ghost_color', Vector4(0.96, 0.80, 0.42, 0.78))
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.riverMist:
        mat.parameters
          ..setVec4('mist_cool', Vector4(0.38, 0.62, 0.72, 1))
          ..setVec4('mist_warm', Vector4(0.88, 0.68, 0.44, 1))
          ..setFloat('mist_opacity', 0.68)
          ..setFloat('night_mix', 0)
          ..setFloat('mist_mode', 0)
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.lanternHaze:
        mat.parameters
          ..setVec4('mist_cool', Vector4(0.38, 0.62, 0.72, 1))
          ..setVec4('mist_warm', Vector4(0.96, 0.56, 0.22, 1))
          ..setFloat('mist_opacity', 0.24)
          ..setFloat('night_mix', 0)
          ..setFloat('mist_mode', 1)
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.airborneMotes:
        mat.parameters
          ..setFloat('dusk_gain', 1)
          ..setFloat('night_gain', 0)
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.mountainVista:
        mat.parameters
          ..setVec4('haze_color', Vector4(0.068, 0.090, 0.175, 1))
          ..setVec4('sun_rim_color', Vector4(0.34, 0.17, 0.08, 1))
          ..setFloat('night_mix', 0)
          ..setFloat('texture_scale', 1);
      case ShukubaSurfaceRole.paintedClouds:
        mat.parameters
          ..setFloat('night_mix', 0)
          ..setFloat('opacity', 0.88)
          ..setFloat('time_sec', 0);
    }
  }
}

class _MutableLanternCluster {
  new(Vec3 initial, this.firstIndex)
    : _sumX = initial.x,
      _sumY = initial.y,
      _sumZ = initial.z,
      weight = 1;

  final int firstIndex;
  double _sumX;
  double _sumY;
  double _sumZ;
  int weight;

  Vec3 get centroid => Vec3(_sumX / weight, _sumY / weight, _sumZ / weight);

  void add(Vec3 point) {
    _sumX += point.x;
    _sumY += point.y;
    _sumZ += point.z;
    weight += 1;
  }
}

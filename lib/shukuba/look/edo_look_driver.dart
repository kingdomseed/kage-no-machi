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

  static final Expando<Material> _sunbeamByRiverMist = Expando<Material>(
    'komorebi_sunbeam',
  );

  final bool allowHeadlessFallback;

  final Map<ShukubaSurfaceRole, Material> _materials = {};
  final List<DecalNode> _decalNodes = [];
  final List<PreprocessedMaterial> _decalMaterials = [];
  final List<Node> _lanternNodes = [];
  final List<PointLight> _lanternLights = [];

  Scene? _scene;
  SumiInkPass? _sumiPass;
  PreprocessedMaterial? _sunbeamMaterial;
  DirectionalLight? _keyLight;
  PhysicalSkySource? _skySource;
  SkyEnvironment? _skyEnvironment;
  EnvironmentSettings? _duskSettings;
  EnvironmentSettings? _nightSettings;

  double _lastSkyTimeValue = -1;

  DirectionalLight? get keyLight => _keyLight;

  List<PointLight> get activeLanternLights => List<PointLight>.unmodifiable([
    for (final light in _lanternLights)
      if (light.intensity > 0) light,
  ]);

  static Material resolveSunbeamMaterial(
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final mistMat = resolveMaterial(ShukubaSurfaceRole.riverMist);
    return _sunbeamByRiverMist[mistMat] ?? mistMat;
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

  @override
  Future<void> attach(Scene scene) async {
    _scene = scene;

    if (!allowHeadlessFallback) {
      await Scene.initializeStaticResources();
      await _loadProductionMaterials();
      await _loadSumiInkPass(scene);
      await _loadDecalPool(scene);
    } else {
      try {
        await Scene.initializeStaticResources();
      } on Object catch (_) {}
      await _loadHeadlessFallback(scene);
    }

    _setupLightingAndSky(scene);
  }

  Future<void> _loadProductionMaterials() async {
    for (final role in ShukubaSurfaceRole.values) {
      final fmatPath = _fmatPathForRole(role);
      final mat = await loadFmatMaterial(fmatPath);
      mat.depthLayer = role.depthLayer;
      _configureRoleParameters(role, mat);
      _materials[role] = mat;
    }

    final sunbeamMat = await loadFmatMaterial(
      'assets/materials/atmosphere_mist.fmat',
    );
    sunbeamMat.depthLayer = ShukubaSurfaceRole.riverMist.depthLayer;
    sunbeamMat.parameters
      ..setVec4('mist_cool', Vector4(0.42, 0.64, 0.72, 1))
      ..setVec4('mist_warm', Vector4(1, 0.78, 0.44, 1))
      ..setVec4(
        'sun_ray_dir',
        _dirToVec4(TimeOfDayRig.goldenDusk.celestialRayDirection),
      )
      ..setFloat('mist_opacity', 0.78)
      ..setFloat('night_mix', 0)
      ..setFloat('mist_mode', 2)
      ..setFloat('time_sec', 0);
    _sunbeamMaterial = sunbeamMat;
    final riverMistMat = _materials[ShukubaSurfaceRole.riverMist];
    if (riverMistMat != null) {
      _sunbeamByRiverMist[riverMistMat] = sunbeamMat;
    }
  }

  Future<void> _loadSumiInkPass(Scene scene) async {
    final key = await gpu.resolveShaderBundleKey('sumi_ink');
    final library = await gpu.loadShaderLibraryAsync(key);
    final shader = library?['SumiInkFragment'];
    if (shader != null) {
      final pass = SumiInkPass(shader);
      _sumiPass = pass;
      scene.addRenderPass(pass);
    }
  }

  Future<void> _loadDecalPool(Scene scene) async {
    for (var i = 0; i < 12; i++) {
      final mat = await loadFmatMaterial(
        'assets/materials/sightcone_decal.fmat',
      );
      _decalMaterials.add(mat);
      final decal = DecalNode(material: mat, name: 'sightcone_decal_$i')
        ..visible = false;
      _decalNodes.add(decal);
      scene.root.add(decal);
    }
  }

  Future<void> _loadHeadlessFallback(Scene scene) async {
    try {
      await _loadProductionMaterials();
    } on Object catch (_) {
      for (final role in ShukubaSurfaceRole.values) {
        _materials[role] = defaultShukubaMaterial(role);
      }
      final riverMistMat = _materials[ShukubaSurfaceRole.riverMist];
      if (riverMistMat != null) {
        _sunbeamByRiverMist[riverMistMat] = defaultShukubaMaterial(
          ShukubaSurfaceRole.riverMist,
        );
      }
    }

    try {
      await _loadSumiInkPass(scene);
    } on Object catch (_) {}

    try {
      await _loadDecalPool(scene);
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
      contactShadows: true,
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

    _lanternNodes
      ..forEach(scene.root.remove)
      ..clear();
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
      final sky = PhysicalSkySource(
        sunDirection: TimeOfDayRig.goldenDusk.celestialSkyDirection.toVector3(),
        sunAngularRadius: 0.024,
        rayleighCoefficient: 2.4,
        rayleighColor: Vector3(0.24, 0.42, 0.66),
        mieCoefficient: 0.012,
        mieEccentricity: 0.82,
        mieColor: Vector3(0.96, 0.72, 0.46),
        turbidity: 6.5,
        groundColor: Vector3(0.16, 0.12, 0.09),
        energy: 0.96,
      );
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
      exposure: 0.96,
      colorGradingEnabled: true,
      saturation: 1.22,
      contrast: 1.10,
      temperature: 0.05,
      bloomEnabled: true,
      bloomThreshold: 0.96,
      bloomIntensity: 0.24,
      bloomScatter: 0.74,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      ambientOcclusionIntensity: 1.68,
      ambientOcclusionRadius: 1.05,
      ambientOcclusionPower: 1.85,
      ambientOcclusionMultiBounce: 0.46,
      ambientOcclusionDirectLightAffect: 0.30,
      fogEnabled: true,
      fogColor: Vector3(0.20, 0.31, 0.40),
      fogDensity: 0.0092,
      fogSunInScatter: 0.58,
      fogSunInScatterExponent: 6.5,
      fogSkyColorInfluence: 0.36,
      fogHeight: 1.8,
      fogHeightFalloff: 0.28,
      godRaysEnabled: true,
      godRaysIntensity: 0.82,
      godRaysDensity: 0.72,
      godRaysAnisotropy: 0.76,
      godRaysStepCount: 36,
      godRaysColor: Vector3(1, 0.78, 0.44),
      vignetteEnabled: true,
      vignetteIntensity: 0.24,
    )..fogMode = FogMode.exponential;

    final night = EnvironmentSettings(
      skybox: skyboxInstance,
      skyEnvironment: skyEnvInstance,
      toneMapping: ToneMappingMode.aces,
      exposure: 0.92,
      colorGradingEnabled: true,
      saturation: 1.18,
      contrast: 1.14,
      temperature: -0.05,
      bloomEnabled: true,
      bloomThreshold: 0.72,
      bloomIntensity: 0.40,
      bloomScatter: 0.82,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionBentNormals: true,
      ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      ambientOcclusionIntensity: 1.68,
      ambientOcclusionRadius: 1.05,
      ambientOcclusionPower: 1.85,
      ambientOcclusionMultiBounce: 0.46,
      ambientOcclusionDirectLightAffect: 0.30,
      fogEnabled: true,
      fogColor: Vector3(0.036, 0.088, 0.175),
      fogDensity: 0.0114,
      fogSunInScatter: 0.18,
      fogSunInScatterExponent: 6.5,
      fogSkyColorInfluence: 0.36,
      fogHeight: 1.8,
      fogHeightFalloff: 0.28,
      godRaysEnabled: true,
      godRaysIntensity: 0.20,
      godRaysDensity: 0.72,
      godRaysAnisotropy: 0.76,
      godRaysStepCount: 36,
      godRaysColor: Vector3(0.44, 0.64, 0.94),
      vignetteEnabled: true,
      vignetteIntensity: 0.36,
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
          ..intensity = baseLanternIntensity * weightBoost
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

    if ((_lastSkyTimeValue - rig.value).abs() > 0.008) {
      _lastSkyTimeValue = rig.value;
      final nf = rig.nightFactor;
      final sky = _skySource;
      if (sky != null) {
        sky
          ..sunDirection = rig.celestialSkyDirection.toVector3()
          ..turbidity = 6.5 - 2.3 * nf
          ..energy = 0.96 - 0.80 * nf
          ..rayleighColor = Vector3(
            0.24 * (1 - nf) + 0.16 * nf,
            0.42 * (1 - nf) + 0.34 * nf,
            0.66 * (1 - nf) + 0.76 * nf,
          )
          ..mieColor = Vector3(
            0.96 * (1 - nf) + 0.44 * nf,
            0.72 * (1 - nf) + 0.64 * nf,
            0.46 * (1 - nf) + 0.94 * nf,
          )
          ..groundColor = Vector3(
            0.16 * (1 - nf) + 0.03 * nf,
            0.12 * (1 - nf) + 0.04 * nf,
            0.09 * (1 - nf) + 0.07 * nf,
          );
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

    final sunbeamMat = _sunbeamMaterial;
    if (sunbeamMat != null) {
      final duskBeamOpacity = 0.78 * (1 - rig.nightFactor).clamp(0.0, 1.0);
      sunbeamMat.parameters
        ..setVec4('sun_ray_dir', _dirToVec4(rig.celestialRayDirection))
        ..setFloat('mist_opacity', duskBeamOpacity)
        ..setFloat('night_mix', rig.nightFactor)
        ..setFloat('time_sec', elapsedSeconds);
    }

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
    final scene = _scene;
    if (scene != null) {
      final pass = _sumiPass;
      if (pass != null) {
        scene.removeRenderPass(pass);
        _sumiPass = null;
      }
      _lanternNodes.forEach(scene.root.remove);
      _decalNodes.forEach(scene.root.remove);
    }
    _lanternNodes.clear();
    _lanternLights.clear();
    _decalNodes.clear();
    _decalMaterials.clear();
    _materials.clear();
    _keyLight = null;
    _sunbeamMaterial = null;
    _scene = null;
  }

  static Vector4 _dirToVec4(Vec3 d) => Vector4(d.x, d.y, d.z, 0);

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
    ShukubaSurfaceRole.ghostPreview => 'assets/materials/ghost_preview.fmat',
    ShukubaSurfaceRole.riverMist ||
    ShukubaSurfaceRole.lanternHaze => 'assets/materials/atmosphere_mist.fmat',
    ShukubaSurfaceRole.airborneMotes => 'assets/materials/airborne_motes.fmat',
  };

  static void _configureRoleParameters(
    ShukubaSurfaceRole role,
    PreprocessedMaterial mat,
  ) {
    switch (role) {
      case ShukubaSurfaceRole.packedEarth:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.145, 0.112, 0.072, 1))
          ..setVec4('warm_tint', Vector4(0.262, 0.195, 0.112, 1))
          ..setFloat('roughness_val', 0.92)
          ..setFloat('grain_scale', 5.2)
          ..setFloat('weathering', 0.20)
          ..setFloat('style_id', 5);
      case ShukubaSurfaceRole.ishigakiStone:
      case ShukubaSurfaceRole.steppingStone:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.13, 0.138, 0.152, 1))
          ..setVec4('warm_tint', Vector4(0.21, 0.19, 0.165, 1))
          ..setFloat('roughness_val', 0.84)
          ..setFloat('grain_scale', 9.5)
          ..setFloat('weathering', 0.42)
          ..setFloat('style_id', 3);
      case ShukubaSurfaceRole.laneOverlay:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.272, 0.194, 0.110, 1))
          ..setVec4('warm_tint', Vector4(0.402, 0.290, 0.165, 1))
          ..setFloat('roughness_val', 0.88)
          ..setFloat('grain_scale', 6.4)
          ..setFloat('weathering', 0.18)
          ..setFloat('style_id', 5.5);
      case ShukubaSurfaceRole.plasterWall:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.50, 0.41, 0.30, 1))
          ..setVec4('warm_tint', Vector4(0.66, 0.54, 0.39, 1))
          ..setFloat('roughness_val', 0.85)
          ..setFloat('grain_scale', 11)
          ..setFloat('weathering', 0.34)
          ..setFloat('style_id', 4);
      case ShukubaSurfaceRole.kuraPlaster:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.76, 0.72, 0.64, 1))
          ..setVec4('warm_tint', Vector4(0.88, 0.83, 0.74, 1))
          ..setFloat('roughness_val', 0.82)
          ..setFloat('grain_scale', 10)
          ..setFloat('weathering', 0.22)
          ..setFloat('style_id', 4);
      case ShukubaSurfaceRole.charredTimber:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.068, 0.042, 0.024, 1))
          ..setVec4('warm_tint', Vector4(0.135, 0.082, 0.044, 1))
          ..setFloat('roughness_val', 0.76)
          ..setFloat('grain_scale', 14)
          ..setFloat('weathering', 0.26)
          ..setFloat('style_id', 2);
      case ShukubaSurfaceRole.kawaraTile:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.042, 0.058, 0.092, 1))
          ..setVec4('warm_tint', Vector4(0.078, 0.102, 0.148, 1))
          ..setFloat('roughness_val', 0.46)
          ..setFloat('grain_scale', 12)
          ..setFloat('weathering', 0.28)
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
          ..setVec4('base_tint', Vector4(0.48, 0.052, 0.024, 1))
          ..setVec4('warm_tint', Vector4(0.68, 0.095, 0.036, 1))
          ..setFloat('roughness_val', 0.44)
          ..setFloat('grain_scale', 14)
          ..setFloat('weathering', 0.14)
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
          ..setVec4('leaf_primary', Vector4(0.28, 0.19, 0.10, 1))
          ..setVec4('leaf_secondary', Vector4(0.96, 0.86, 0.54, 1))
          ..setFloat('rim_warmth', 0.48)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.16)
          ..setFloat('foliage_kind', 0);
      case ShukubaSurfaceRole.bambooCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.042, 0.135, 0.028, 1))
          ..setVec4('leaf_secondary', Vector4(0.19, 0.36, 0.062, 1))
          ..setFloat('rim_warmth', 0.36)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.22)
          ..setFloat('foliage_kind', 1);
      case ShukubaSurfaceRole.pineCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.016, 0.058, 0.044, 1))
          ..setVec4('leaf_secondary', Vector4(0.088, 0.215, 0.072, 1))
          ..setFloat('rim_warmth', 0.26)
          ..setFloat('sun_translucency', 0.65)
          ..setFloat('wind_strength', 0.14)
          ..setFloat('foliage_kind', 3);
      case ShukubaSurfaceRole.willowCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.055, 0.148, 0.042, 1))
          ..setVec4('leaf_secondary', Vector4(0.28, 0.44, 0.11, 1))
          ..setFloat('rim_warmth', 0.44)
          ..setFloat('sun_translucency', 1)
          ..setFloat('wind_strength', 0.30)
          ..setFloat('foliage_kind', 4);
      case ShukubaSurfaceRole.groundMeadow:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.50, 0.48, 0.42, 1))
          ..setVec4('leaf_secondary', Vector4(1, 0.94, 0.80, 1))
          ..setFloat('rim_warmth', 0.34)
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
          ..setVec4('shallow_color', Vector4(0.068, 0.215, 0.175, 0.78))
          ..setVec4('deep_color', Vector4(0.015, 0.068, 0.076, 0.95))
          ..setVec4('foam_color', Vector4(0.84, 0.90, 0.87, 0.86))
          ..setFloat('flow_speed', 0.95);
      case ShukubaSurfaceRole.ghostPreview:
        mat.parameters
          ..setVec4('ghost_color', Vector4(0.96, 0.80, 0.42, 0.78))
          ..setFloat('time_sec', 0);
      case ShukubaSurfaceRole.riverMist:
        mat.parameters
          ..setVec4('mist_cool', Vector4(0.38, 0.62, 0.72, 1))
          ..setVec4('mist_warm', Vector4(0.88, 0.68, 0.44, 1))
          ..setVec4(
            'sun_ray_dir',
            _dirToVec4(TimeOfDayRig.goldenDusk.celestialRayDirection),
          )
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

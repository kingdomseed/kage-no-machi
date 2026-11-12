import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:kage_no_machi/shukuba/look/sumi_ink_pass.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

class EdoLookDriver implements ShukubaLookDriver {
  new({this.allowHeadlessFallback = false});

  final bool allowHeadlessFallback;

  final Map<ShukubaSurfaceRole, Material> _materials = {};
  final List<DecalNode> _decalNodes = [];
  final List<PreprocessedMaterial> _decalMaterials = [];
  final List<Node> _lanternNodes = [];
  final List<PointLight> _lanternLights = [];

  Scene? _scene;
  SumiInkPass? _sumiPass;
  DirectionalLight? _keyLight;
  DirectionalLight? _fillLight;
  Node? _fillLightNode;
  GradientSkySource? _skySource;
  SkyEnvironment? _skyEnvironment;
  EnvironmentSettings? _duskSettings;
  EnvironmentSettings? _nightSettings;

  double _lastNightFactor = -1;

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
    }

    try {
      await _loadSumiInkPass(scene);
    } on Object catch (_) {}

    try {
      await _loadDecalPool(scene);
    } on Object catch (_) {}
  }

  void _setupLightingAndSky(Scene scene) {
    _keyLight = DirectionalLight(
      castsShadow: true,
      priority: 10,
      shadowCascadeCount: 3,
      shadowMaxDistance: 95,
      shadowMapResolution: 2048,
      shadowFilter: DirectionalShadowFilter.pcss,
      shadowAmbientStrength: 0.15,
      contactShadows: true,
    );
    scene.directionalLight = _keyLight;

    _fillLight = DirectionalLight(
      intensity: 0.24,
      color: Vector3(0.24, 0.38, 0.58),
    );
    _fillLightNode = Node(name: 'edo_fill_light')
      ..addComponent(
        DirectionalLightComponent.aimed(
          _fillLight!,
          Vector3(0.3, -1, 0.4).normalized(),
        ),
      );
    scene.root.add(_fillLightNode!);

    for (var i = 0; i < 16; i++) {
      final light = PointLight(
        color: Vector3(1, 0.56, 0.20),
        intensity: 0,
        range: 10.5,
      );
      final node = Node(name: 'lantern_light_$i')
        ..addComponent(PointLightComponent(light))
        ..visible = false;
      _lanternLights.add(light);
      _lanternNodes.add(node);
      scene.root.add(node);
    }

    try {
      final sky = GradientSkySource(
        zenithColor: Vector3(0.12, 0.28, 0.58),
        horizonColor: Vector3(0.88, 0.52, 0.26),
        groundColor: Vector3(0.14, 0.11, 0.09),
        sunDirection: Vector3(-0.4, 0.8, -0.4).normalized(),
        sunColor: Vector3(4.6, 3, 1.45),
      );
      _skySource = sky;
      final skyboxInstance = Skybox(sky);
      final skyEnvInstance = SkyEnvironment(sky);
      _skyEnvironment = skyEnvInstance;

      scene
        ..skybox = skyboxInstance
        ..skyEnvironment = skyEnvInstance
        ..antiAliasingMode = AntiAliasingMode.msaa;

      final dusk = EnvironmentSettings(
        skybox: skyboxInstance,
        skyEnvironment: skyEnvInstance,
        toneMapping: ToneMappingMode.aces,
        exposure: 1.02,
        colorGradingEnabled: true,
        saturation: 1.22,
        contrast: 1.10,
        temperature: 0.05,
        bloomEnabled: true,
        bloomThreshold: 0.95,
        bloomIntensity: 0.26,
        bloomScatter: 0.74,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionIntensity: 1.56,
        ambientOcclusionPower: 1.75,
        ambientOcclusionRadius: 0.88,
        ambientOcclusionBentNormals: true,
        ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
        fogEnabled: true,
        fogColor: Vector3(0.18, 0.30, 0.38),
        fogDensity: 0.0086,
        fogHeight: 1.35,
        fogHeightFalloff: 0.34,
        godRaysEnabled: true,
        godRaysIntensity: 0.42,
        godRaysDensity: 0.66,
        godRaysColor: Vector3(1, 0.80, 0.48),
        vignetteEnabled: true,
        vignetteIntensity: 0.24,
      );

      final night = EnvironmentSettings(
        skybox: skyboxInstance,
        skyEnvironment: skyEnvInstance,
        toneMapping: ToneMappingMode.aces,
        exposure: 0.98,
        colorGradingEnabled: true,
        saturation: 1.18,
        contrast: 1.14,
        temperature: -0.05,
        bloomEnabled: true,
        bloomThreshold: 0.72,
        bloomIntensity: 0.42,
        bloomScatter: 0.82,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionIntensity: 1.56,
        ambientOcclusionPower: 1.85,
        ambientOcclusionRadius: 0.88,
        ambientOcclusionBentNormals: true,
        ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
        fogEnabled: true,
        fogColor: Vector3(0.036, 0.088, 0.175),
        fogDensity: 0.0112,
        fogHeight: 1.75,
        fogHeightFalloff: 0.30,
        godRaysEnabled: true,
        godRaysIntensity: 0.15,
        godRaysDensity: 0.52,
        godRaysColor: Vector3(0.42, 0.62, 0.94),
        vignetteEnabled: true,
        vignetteIntensity: 0.36,
      );

      _duskSettings = dusk;
      _nightSettings = night;
      scene.environmentSettings = dusk;
    } on Object catch (_) {
      if (!allowHeadlessFallback) rethrow;
    }
  }

  @override
  void syncFrame({
    required TimeOfDayRig rig,
    required MagistrateVisionState vision,
    required List<WatchSightcone> sightcones,
    required List<Vec3> lanternOrigins,
    required double elapsedSeconds,
  }) {
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

    if ((_lastNightFactor - rig.nightFactor).abs() > 0.02) {
      _lastNightFactor = rig.nightFactor;
      final sky = _skySource;
      if (sky != null) {
        sky
          ..sunDirection = rig.celestialSkyDirection.toVector3()
          ..sunColor = Vector3(
            4.2 * (1 - rig.nightFactor) + 1.2 * rig.nightFactor,
            2.8 * (1 - rig.nightFactor) + 1.6 * rig.nightFactor,
            1.4 * (1 - rig.nightFactor) + 2.4 * rig.nightFactor,
          )
          ..zenithColor = Vector3(
            0.18 * (1 - rig.nightFactor) + 0.02 * rig.nightFactor,
            0.32 * (1 - rig.nightFactor) + 0.04 * rig.nightFactor,
            0.62 * (1 - rig.nightFactor) + 0.12 * rig.nightFactor,
          )
          ..horizonColor = Vector3(
            0.92 * (1 - rig.nightFactor) + 0.10 * rig.nightFactor,
            0.54 * (1 - rig.nightFactor) + 0.16 * rig.nightFactor,
            0.28 * (1 - rig.nightFactor) + 0.32 * rig.nightFactor,
          )
          ..groundColor = Vector3(
            0.20 * (1 - rig.nightFactor) + 0.04 * rig.nightFactor,
            0.14 * (1 - rig.nightFactor) + 0.04 * rig.nightFactor,
            0.10 * (1 - rig.nightFactor) + 0.06 * rig.nightFactor,
          );
        _skyEnvironment?.invalidate();
      }
    }

    final key = _keyLight;
    if (key != null) {
      key
        ..direction = rig.celestialRayDirection.toVector3()
        ..color = rig.celestialLinearRgb.toVector3()
        ..intensity = rig.celestialIntensity
        ..shadowAmbientStrength = 0.15 + 0.05 * rig.nightFactor;
    }

    final fill = _fillLight;
    if (fill != null) {
      fill
        ..intensity = 0.24
        ..color = Vector3(0.24, 0.38, 0.58);
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

    final lanternIntensity = rig.lanternPointLightIntensity;
    final lanternRange = rig.lanternPointLightRange;
    for (var i = 0; i < _lanternNodes.length; i++) {
      if (i < lanternOrigins.length) {
        _lanternNodes[i].position = lanternOrigins[i].toVector3();
        _lanternLights[i]
          ..intensity = lanternIntensity
          ..range = lanternRange;
        _lanternNodes[i].visible = true;
      } else {
        _lanternLights[i].intensity = 0;
        _lanternNodes[i].visible = false;
      }
    }

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
      final fillNode = _fillLightNode;
      if (fillNode != null) {
        scene.root.remove(fillNode);
        _fillLightNode = null;
      }
      _lanternNodes.forEach(scene.root.remove);
      _decalNodes.forEach(scene.root.remove);
    }
    _lanternNodes.clear();
    _lanternLights.clear();
    _decalNodes.clear();
    _decalMaterials.clear();
    _materials.clear();
    _scene = null;
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
          ..setVec4('base_tint', Vector4(0.175, 0.138, 0.088, 1))
          ..setVec4('warm_tint', Vector4(0.305, 0.228, 0.132, 1))
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
          ..setVec4('base_tint', Vector4(0.33, 0.235, 0.135, 1))
          ..setVec4('warm_tint', Vector4(0.47, 0.340, 0.195, 1))
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

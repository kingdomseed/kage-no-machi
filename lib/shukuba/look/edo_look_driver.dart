import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:kage_no_machi/shukuba/look/sumi_ink_pass.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

/// Shukuba look driver producing painterly Edo gouache surfaces,
/// translucent shōji & chōchin paper, wind-swayed maple & bamboo foliage,
/// depth-absorbed river water, and Shadow Tactics vision cones.
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
  Skybox? _skybox;
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
      await _loadProductionMaterials();
      await _loadSumiInkPass(scene);
      await _loadDecalPool(scene);
    } else {
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
      shadowAmbientStrength: 0.32,
      contactShadows: true,
    );
    scene.directionalLight = _keyLight;

    _fillLight = DirectionalLight(
      intensity: 0.65,
      color: Vector3(0.38, 0.48, 0.72),
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
        color: Vector3(1, 0.65, 0.28),
        intensity: 0,
        range: 8,
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
        zenithColor: Vector3(0.18, 0.32, 0.62),
        horizonColor: Vector3(0.92, 0.54, 0.28),
        groundColor: Vector3(0.20, 0.14, 0.10),
        sunDirection: Vector3(-0.4, 0.8, -0.4).normalized(),
        sunColor: Vector3(4.2, 2.8, 1.4),
      );
      _skySource = sky;
      final skyboxInstance = Skybox(sky);
      final skyEnvInstance = SkyEnvironment(sky);
      _skybox = skyboxInstance;
      _skyEnvironment = skyEnvInstance;

      scene
        ..skybox = skyboxInstance
        ..skyEnvironment = skyEnvInstance
        ..antiAliasingMode = AntiAliasingMode.msaa;

      final dusk = EnvironmentSettings(
        skybox: skyboxInstance,
        skyEnvironment: skyEnvInstance,
        toneMapping: ToneMappingMode.agx,
        agxContrast: 1.35,
        bloomEnabled: true,
        bloomThreshold: 1.05,
        bloomIntensity: 0.22,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionIntensity: 1.15,
        ambientOcclusionPower: 1.6,
        ambientOcclusionRadius: 0.35,
        fogEnabled: true,
        fogColor: Vector3(0.72, 0.48, 0.32),
        fogDensity: 0.0035,
        fogHeight: 1.2,
        fogHeightFalloff: 0.15,
        vignetteEnabled: true,
        vignetteIntensity: 0.22,
      );

      final night = EnvironmentSettings(
        skybox: skyboxInstance,
        skyEnvironment: skyEnvInstance,
        toneMapping: ToneMappingMode.agx,
        agxContrast: 1.35,
        exposure: 0.88,
        bloomEnabled: true,
        bloomThreshold: 0.85,
        bloomIntensity: 0.32,
        bloomScatter: 0.75,
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionIntensity: 1.35,
        ambientOcclusionPower: 1.8,
        ambientOcclusionRadius: 0.38,
        fogEnabled: true,
        fogColor: Vector3(0.08, 0.12, 0.22),
        fogDensity: 0.0055,
        fogHeight: 1.5,
        fogHeightFalloff: 0.12,
        vignetteEnabled: true,
        vignetteIntensity: 0.35,
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
      if (_skybox != null) {
        scene.skybox = _skybox;
      }
      if (_skyEnvironment != null) {
        scene.skyEnvironment = _skyEnvironment;
      }
    }

    if ((_lastNightFactor - rig.nightFactor).abs() > 0.02) {
      _lastNightFactor = rig.nightFactor;
      final sky = _skySource;
      if (sky != null) {
        final cDir = rig.celestialDirection;
        sky
          ..sunDirection = Vector3(-cDir.x, -cDir.y, -cDir.z).normalized()
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
        ..direction = rig.celestialDirection.toVector3()
        ..color = rig.celestialLinearRgb.toVector3()
        ..intensity = rig.celestialIntensity
        ..shadowAmbientStrength = 0.28 + 0.10 * rig.nightFactor;
    }

    final fill = _fillLight;
    if (fill != null) {
      fill.intensity = 0.45 + 0.25 * (1 - rig.nightFactor);
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
    _setParamFloat(ShukubaSurfaceRole.mapleCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(ShukubaSurfaceRole.bambooCanopy, 'time_sec', elapsedSeconds);
    _setParamFloat(ShukubaSurfaceRole.riverWater, 'time_sec', elapsedSeconds);

    for (var i = 0; i < _lanternNodes.length; i++) {
      if (i < lanternOrigins.length) {
        _lanternNodes[i].position = lanternOrigins[i].toVector3();
        _lanternLights[i]
          ..intensity = rig.lanternPointLightIntensity
          ..range = rig.lanternPointLightRange;
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
              ..setFloat(
                'cone_range_norm',
                cone.rangeMeters / cone.decalBoxSize,
              )
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
    ShukubaSurfaceRole.laneOverlay ||
    ShukubaSurfaceRole.plasterWall ||
    ShukubaSurfaceRole.charredTimber ||
    ShukubaSurfaceRole.kawaraTile ||
    ShukubaSurfaceRole.fabricAwning => 'assets/materials/gouache_lit.fmat',
    ShukubaSurfaceRole.shojiScreen ||
    ShukubaSurfaceRole.chochinLantern => 'assets/materials/shoji_lantern.fmat',
    ShukubaSurfaceRole.mapleCanopy ||
    ShukubaSurfaceRole.bambooCanopy => 'assets/materials/foliage_canopy.fmat',
    ShukubaSurfaceRole.riverWater => 'assets/materials/river_water.fmat',
  };

  static void _configureRoleParameters(
    ShukubaSurfaceRole role,
    PreprocessedMaterial mat,
  ) {
    switch (role) {
      case ShukubaSurfaceRole.packedEarth:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.36, 0.30, 0.24, 1))
          ..setVec4('warm_tint', Vector4(0.48, 0.40, 0.32, 1))
          ..setFloat('roughness_val', 0.94)
          ..setFloat('grain_scale', 7)
          ..setFloat('weathering', 0.18);
      case ShukubaSurfaceRole.ishigakiStone:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.42, 0.43, 0.45, 1))
          ..setVec4('warm_tint', Vector4(0.50, 0.48, 0.46, 1))
          ..setFloat('roughness_val', 0.88)
          ..setFloat('grain_scale', 9.5)
          ..setFloat('weathering', 0.35);
      case ShukubaSurfaceRole.laneOverlay:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.49, 0.41, 0.31, 1))
          ..setVec4('warm_tint', Vector4(0.58, 0.48, 0.38, 1))
          ..setFloat('roughness_val', 0.92)
          ..setFloat('grain_scale', 8)
          ..setFloat('weathering', 0.22);
      case ShukubaSurfaceRole.plasterWall:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.85, 0.81, 0.75, 1))
          ..setVec4('warm_tint', Vector4(0.92, 0.88, 0.82, 1))
          ..setFloat('roughness_val', 0.85)
          ..setFloat('grain_scale', 11)
          ..setFloat('weathering', 0.30);
      case ShukubaSurfaceRole.charredTimber:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.23, 0.18, 0.15, 1))
          ..setVec4('warm_tint', Vector4(0.30, 0.22, 0.18, 1))
          ..setFloat('roughness_val', 0.82)
          ..setFloat('grain_scale', 14)
          ..setFloat('weathering', 0.25);
      case ShukubaSurfaceRole.kawaraTile:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.16, 0.19, 0.23, 1))
          ..setVec4('warm_tint', Vector4(0.24, 0.26, 0.30, 1))
          ..setFloat('roughness_val', 0.64)
          ..setFloat('grain_scale', 12)
          ..setFloat('weathering', 0.20);
      case ShukubaSurfaceRole.fabricAwning:
        mat.parameters
          ..setVec4('base_tint', Vector4(0.62, 0.25, 0.17, 1))
          ..setVec4('warm_tint', Vector4(0.75, 0.35, 0.22, 1))
          ..setFloat('roughness_val', 0.86)
          ..setFloat('grain_scale', 16)
          ..setFloat('weathering', 0.15);
      case ShukubaSurfaceRole.shojiScreen:
        mat.parameters
          ..setVec4('paper_color', Vector4(0.96, 0.88, 0.72, 1))
          ..setVec4('glow_color', Vector4(1, 0.72, 0.35, 1))
          ..setFloat('emissive_gain', 0.12)
          ..setFloat('rib_freq', 16);
      case ShukubaSurfaceRole.chochinLantern:
        mat.parameters
          ..setVec4('paper_color', Vector4(0.98, 0.75, 0.45, 1))
          ..setVec4('glow_color', Vector4(1, 0.58, 0.20, 1))
          ..setFloat('emissive_gain', 0.35)
          ..setFloat('rib_freq', 20);
      case ShukubaSurfaceRole.mapleCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.78, 0.27, 0.16, 1))
          ..setVec4('leaf_secondary', Vector4(0.94, 0.48, 0.18, 1))
          ..setFloat('rim_warmth', 0.35)
          ..setFloat('wind_strength', 0.18);
      case ShukubaSurfaceRole.bambooCanopy:
        mat.parameters
          ..setVec4('leaf_primary', Vector4(0.31, 0.47, 0.26, 1))
          ..setVec4('leaf_secondary', Vector4(0.48, 0.62, 0.32, 1))
          ..setFloat('rim_warmth', 0.30)
          ..setFloat('wind_strength', 0.22);
      case ShukubaSurfaceRole.riverWater:
        mat.parameters
          ..setVec4('shallow_color', Vector4(0.16, 0.35, 0.39, 0.75))
          ..setVec4('deep_color', Vector4(0.06, 0.15, 0.24, 0.95))
          ..setVec4('foam_color', Vector4(0.90, 0.95, 0.95, 0.85))
          ..setFloat('flow_speed', 0.85);
    }
  }
}

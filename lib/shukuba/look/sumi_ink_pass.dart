import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart'
    show CustomRenderPass, RenderInput, RenderPassContext, RenderStage;
import 'package:vector_math/vector_math.dart' show Vector4;

/// Tunable parameters packed into the 32-byte std140 `SumiInkParams` block:
/// `layout(std140) uniform SumiInkParams { vec4 ink_color; vec4 weights; }`.
@immutable
class SumiInkParams {
  new({
    Vector4? inkColor,
    this.depthWeight = defaultDepthWeight,
    this.normalWeight = defaultNormalWeight,
    this.washiGrainStrength = defaultWashiGrainStrength,
    this.skyFadeDistance = defaultSkyFadeDistance,
  }) : inkColor = inkColor ?? Vector4(0.12, 0.09, 0.08, 0.95);

  static const double defaultDepthWeight = 1.8;
  static const double defaultNormalWeight = 1.5;
  static const double defaultWashiGrainStrength = 0.014;
  static const double defaultSkyFadeDistance = 260;

  final Vector4 inkColor;
  final double depthWeight;
  final double normalWeight;
  final double washiGrainStrength;
  final double skyFadeDistance;

  ByteData packStd140() {
    final list = Float32List(8)
      ..[0] = inkColor.x
      ..[1] = inkColor.y
      ..[2] = inkColor.z
      ..[3] = inkColor.w
      ..[4] = depthWeight
      ..[5] = normalWeight
      ..[6] = washiGrainStrength
      ..[7] = skyFadeDistance;
    return ByteData.sublistView(list);
  }

  SumiInkParams copyWith({
    Vector4? inkColor,
    double? depthWeight,
    double? normalWeight,
    double? washiGrainStrength,
    double? skyFadeDistance,
  }) => SumiInkParams(
    inkColor: inkColor ?? this.inkColor,
    depthWeight: depthWeight ?? this.depthWeight,
    normalWeight: normalWeight ?? this.normalWeight,
    washiGrainStrength: washiGrainStrength ?? this.washiGrainStrength,
    skyFadeDistance: skyFadeDistance ?? this.skyFadeDistance,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SumiInkParams &&
          other.inkColor == inkColor &&
          other.depthWeight == depthWeight &&
          other.normalWeight == normalWeight &&
          other.washiGrainStrength == washiGrainStrength &&
          other.skyFadeDistance == skyFadeDistance;

  @override
  int get hashCode => Object.hash(
    inkColor,
    depthWeight,
    normalWeight,
    washiGrainStrength,
    skyFadeDistance,
  );
}

class SumiInkPass extends CustomRenderPass {
  new(this.shader, {SumiInkParams? params})
    : params = params ?? SumiInkParams();

  final gpu.Shader shader;
  SumiInkParams params;

  @override
  String get name => 'sumi_ink';

  @override
  RenderStage get stage => RenderStage.afterToneMapping;

  @override
  Set<RenderInput> get inputs => const {RenderInput.depth, RenderInput.normals};

  @override
  void execute(RenderPassContext context) {
    final depthTex = context.sceneDepthLinear;
    if (depthTex == null) {
      return;
    }
    context.applyShader(
      shader,
      textures: {'scene_depth_linear': depthTex},
      uniforms: {'SumiInkParams': params.packStd140()},
      frameInfo: true,
    );
  }
}

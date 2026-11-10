#version 460 core

#include <octahedral.glsl>

uniform sampler2D input_color;
uniform sampler2D scene_depth_linear;

layout(std140) uniform PostFrameInfo {
  vec2 resolution;
  vec2 texel_size;
  float time;
  float _pad0;
  float _pad1;
  float _pad2;
} frame_info;

layout(std140) uniform SumiInkParams {
  vec4 ink_color;
  vec4 weights;
} ink_params;

in vec2 v_uv;
out vec4 frag_color;

void main() {
  vec4 base = texture(input_color, v_uv);
  vec4 centerSample = texture(scene_depth_linear, v_uv);
  float centerDepth = centerSample.r;

  float skyDistance = ink_params.weights.w;
  float skyFade = clamp((skyDistance - centerDepth) * 0.05, 0.0, 1.0);

  vec2 d = frame_info.texel_size;
  vec4 sLeft = texture(scene_depth_linear, v_uv - vec2(d.x, 0.0));
  vec4 sRight = texture(scene_depth_linear, v_uv + vec2(d.x, 0.0));
  vec4 sBottom = texture(scene_depth_linear, v_uv - vec2(0.0, d.y));
  vec4 sTop = texture(scene_depth_linear, v_uv + vec2(0.0, d.y));

  float denom = max(centerDepth, 0.5);
  float depthDiffH = (sRight.r - sLeft.r) / denom;
  float depthDiffV = (sTop.r - sBottom.r) / denom;
  float depthGrad = sqrt(depthDiffH * depthDiffH + depthDiffV * depthDiffV);
  float maxDepthStep = max(
    max(abs(sLeft.r - centerDepth), abs(sRight.r - centerDepth)),
    max(abs(sTop.r - centerDepth), abs(sBottom.r - centerDepth))
  ) / denom;
  float depthEdge = clamp(
    max(depthGrad, maxDepthStep * 1.5) * ink_params.weights.x * 3.5,
    0.0,
    1.0
  );

  vec3 nCenter = OctDecode(centerSample.gb);
  vec3 nLeft = OctDecode(sLeft.gb);
  vec3 nRight = OctDecode(sRight.gb);
  vec3 nBottom = OctDecode(sBottom.gb);
  vec3 nTop = OctDecode(sTop.gb);

  float creaseTerm =
      (1.0 - dot(nCenter, nLeft)) +
      (1.0 - dot(nCenter, nRight)) +
      (1.0 - dot(nCenter, nBottom)) +
      (1.0 - dot(nCenter, nTop));
  float normalCrease =
      clamp(creaseTerm * 0.25 * ink_params.weights.y * 2.2, 0.0, 1.0) * skyFade;

  float edge = clamp(max(depthEdge, normalCrease), 0.0, 1.0);
  vec3 inkModulated = mix(
    base.rgb,
    base.rgb * ink_params.ink_color.rgb,
    edge * ink_params.ink_color.a
  );

  float grainNoise = fract(
    sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453
  );
  float grainScale = (grainNoise - 0.5) * 2.0 * ink_params.weights.z;
  vec3 finalRgb = clamp(inkModulated + inkModulated * grainScale, 0.0, 1.0);

  frag_color = vec4(finalRgb, base.a);
}

#version 460 core

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

vec3 DecodeDepthPrepassNormal(vec2 e) {
  vec3 n = vec3(e.x, e.y, 1.0 - abs(e.x) - abs(e.y));
  if (n.z < 0.0) {
    vec2 s = vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    n.xy = (1.0 - abs(n.yx)) * s;
  }
  float len = length(n);
  return len > 1e-5 ? (n / len) : vec3(0.0, 0.0, -1.0);
}

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

  float denom = max(centerDepth, 1.2);
  float distAtten = clamp(1.20 - centerDepth * 0.0046, 0.50, 1.0);
  float lapH = abs(sLeft.r + sRight.r - 2.0 * centerDepth) / denom;
  float lapV = abs(sTop.r + sBottom.r - 2.0 * centerDepth) / denom;
  float laplacian = (lapH + lapV) * ink_params.weights.x;
  float depthEdge = smoothstep(0.015, 0.058, laplacian) * skyFade * distAtten;

  vec3 nCenter = DecodeDepthPrepassNormal(centerSample.gb);
  vec3 nLeft = DecodeDepthPrepassNormal(sLeft.gb);
  vec3 nRight = DecodeDepthPrepassNormal(sRight.gb);
  vec3 nBottom = DecodeDepthPrepassNormal(sBottom.gb);
  vec3 nTop = DecodeDepthPrepassNormal(sTop.gb);

  float creaseRaw =
      (1.0 - dot(nCenter, nLeft)) +
      (1.0 - dot(nCenter, nRight)) +
      (1.0 - dot(nCenter, nBottom)) +
      (1.0 - dot(nCenter, nTop));
  float scaledCrease = creaseRaw * ink_params.weights.y * 0.62;
  float normalCrease =
      smoothstep(0.18, 0.68, scaledCrease) * skyFade * distAtten;

  float maxRough = max(
    centerSample.a,
    max(max(sLeft.a, sRight.a), max(sBottom.a, sTop.a))
  );
  float botanicalDamp = 1.0
      - 0.78 * smoothstep(0.960, 0.980, maxRough)
      - 0.16 * smoothstep(0.986, 0.992, maxRough);
  float edge =
      clamp(max(depthEdge, normalCrease * 0.82), 0.0, 1.0) * botanicalDamp;
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

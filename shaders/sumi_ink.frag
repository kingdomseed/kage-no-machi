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

vec3 SampleDepthGatedColor(
  vec2 uv,
  float centerDepth,
  float depthTol,
  vec3 fallbackRgb
) {
  float d = texture(scene_depth_linear, uv).r;
  if (abs(d - centerDepth) > depthTol) {
    return fallbackRgb;
  }
  return texture(input_color, uv).rgb;
}

vec3 EvalSectorMeanAndVar(
  vec2 baseUv,
  vec2 stepUv,
  vec2 dirSign,
  float centerDepth,
  float depthTol,
  vec3 fallbackRgb,
  out float outVariance
) {
  vec3 sum = vec3(0.0);
  float lumaSum = 0.0;
  float lumaSqSum = 0.0;
  for (int j = 0; j < 2; j++) {
    for (int i = 0; i < 2; i++) {
      vec2 offset = vec2(float(i) * dirSign.x, float(j) * dirSign.y) * stepUv;
      vec3 c = SampleDepthGatedColor(
        baseUv + offset,
        centerDepth,
        depthTol,
        fallbackRgb
      );
      sum += c;
      float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
      lumaSum += lum;
      lumaSqSum += lum * lum;
    }
  }
  vec3 meanRgb = sum * 0.25;
  float meanLum = lumaSum * 0.25;
  outVariance = max(0.0, lumaSqSum * 0.25 - meanLum * meanLum);
  return meanRgb;
}

void main() {
  vec4 base = texture(input_color, v_uv);
  vec4 centerSample = texture(scene_depth_linear, v_uv);
  float centerDepth = centerSample.r;

  float skyDistance = ink_params.weights.w;
  float skyFade = clamp((skyDistance - centerDepth) * 0.05, 0.0, 1.0);

  vec2 d = frame_info.texel_size;
  float inkWarpX =
      sin(v_uv.y * frame_info.resolution.y * 0.055 + v_uv.x * 19.0) * 0.35 * d.x;
  float inkWarpY =
      cos(v_uv.x * frame_info.resolution.x * 0.055 - v_uv.y * 17.0) * 0.35 * d.y;
  vec2 edgeUv = v_uv + vec2(inkWarpX, inkWarpY);

  vec4 sLeft = texture(scene_depth_linear, edgeUv - vec2(d.x, 0.0));
  vec4 sRight = texture(scene_depth_linear, edgeUv + vec2(d.x, 0.0));
  vec4 sBottom = texture(scene_depth_linear, edgeUv - vec2(0.0, d.y));
  vec4 sTop = texture(scene_depth_linear, edgeUv + vec2(0.0, d.y));

  // Prevent huge depth jumps onto distant sky/ocean horizons from tracing heavy black contours.
  float maxNeighborDepth = max(
    max(sLeft.r, sRight.r),
    max(sBottom.r, sTop.r)
  );
  float horizonMask = clamp(
    (skyDistance * 0.78 - maxNeighborDepth) / max(skyDistance * 0.16, 1.0),
    0.0,
    1.0
  );
  float dLeft = min(sLeft.r, centerDepth + 12.0);
  float dRight = min(sRight.r, centerDepth + 12.0);
  float dBottom = min(sBottom.r, centerDepth + 12.0);
  float dTop = min(sTop.r, centerDepth + 12.0);

  float denom = max(centerDepth, 1.2);
  float distAtten = clamp(1.0 - smoothstep(24.0, 82.0, centerDepth) * 0.85, 0.15, 1.0);
  float lapH = abs(dLeft + dRight - 2.0 * centerDepth) / denom;
  float lapV = abs(dTop + dBottom - 2.0 * centerDepth) / denom;
  float laplacian = (lapH + lapV) * ink_params.weights.x;
  float depthEdge =
      smoothstep(0.022, 0.075, laplacian) * skyFade * distAtten * horizonMask;

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
  float scaledCrease = creaseRaw * ink_params.weights.y * 0.56;
  float normalCrease =
      smoothstep(0.24, 0.78, scaledCrease) * skyFade * distAtten * horizonMask;

  float maxRough = max(
    centerSample.a,
    max(max(sLeft.a, sRight.a), max(sBottom.a, sTop.a))
  );
  float botanicalDamp = 1.0
      - 0.78 * smoothstep(0.960, 0.980, maxRough)
      - 0.16 * smoothstep(0.986, 0.992, maxRough);
  float edge =
      clamp(max(depthEdge, normalCrease * 0.78), 0.0, 1.0) * botanicalDamp;

  float depthTol = max(0.25, centerDepth * 0.035);
  float v0;
  float v1;
  float v2;
  float v3;
  vec3 m0 = EvalSectorMeanAndVar(v_uv, d, vec2(-1.0, -1.0), centerDepth, depthTol, base.rgb, v0);
  vec3 m1 = EvalSectorMeanAndVar(v_uv, d, vec2(1.0, -1.0), centerDepth, depthTol, base.rgb, v1);
  vec3 m2 = EvalSectorMeanAndVar(v_uv, d, vec2(-1.0, 1.0), centerDepth, depthTol, base.rgb, v2);
  vec3 m3 = EvalSectorMeanAndVar(v_uv, d, vec2(1.0, 1.0), centerDepth, depthTol, base.rgb, v3);

  vec3 kuwaharaRgb = m0;
  float minVar = v0;
  if (v1 < minVar) {
    minVar = v1;
    kuwaharaRgb = m1;
  }
  if (v2 < minVar) {
    minVar = v2;
    kuwaharaRgb = m2;
  }
  if (v3 < minVar) {
    kuwaharaRgb = m3;
  }

  float kuwaharaMix = 0.14 * skyFade * distAtten * (1.0 - edge * 0.85);
  vec3 painterlyRgb = mix(base.rgb, kuwaharaRgb, kuwaharaMix);

  float luma = dot(painterlyRgb, vec3(0.2126, 0.7152, 0.0722));
  float shadowLift = smoothstep(0.26, 0.02, luma) * skyFade;
  float warmGlaze = smoothstep(0.42, 0.85, luma) * skyFade;
  painterlyRgb += vec3(0.005, 0.014, 0.036) * shadowLift;
  painterlyRgb *= mix(vec3(1.0), vec3(1.05, 1.00, 0.93), warmGlaze);

  float brightDamp = 1.0 - smoothstep(0.55, 0.92, luma) * 0.45;
  vec3 inkModulated = mix(
    painterlyRgb,
    painterlyRgb * ink_params.ink_color.rgb,
    edge * brightDamp * ink_params.ink_color.a
  );

  vec2 px = gl_FragCoord.xy;
  float fiberH = sin(px.y * 0.55 + sin(px.x * 0.09) * 1.4) * 0.5 + 0.5;
  float fiberV = cos(px.x * 0.52 + cos(px.y * 0.08) * 1.4) * 0.5 + 0.5;
  float fineTooth = fract(
    sin(dot(floor(px * 0.5), vec2(12.9898, 78.233))) * 43758.5453
  );
  float washiPaper = mix((fiberH + fiberV) * 0.5, fineTooth, 0.45);
  float grainScale = (washiPaper - 0.5) * 2.0 * ink_params.weights.z * mix(0.22, 1.0, skyFade);
  vec3 finalRgb = clamp(inkModulated + inkModulated * grainScale, 0.0, 1.0);

  frag_color = vec4(finalRgb, base.a);
}

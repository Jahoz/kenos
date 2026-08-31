// KENOS — ether dissolution.
// The echo's body scatters into real particles: each grid cell holds one
// dust mote with its own rest position, departure delay, velocity and
// brightness. Dispersion radiates from the field center with a slow curl,
// drifting slightly upward — like warmth leaving the body.
// Driven entirely by uProgress (no time uniform): deterministic, testable.

#include <flutter/runtime_effect.glsl>

uniform vec2  uSize;     // logical size of the field
uniform float uProgress; // 0 -> 1 dissolution
uniform float uSeed;     // per-echo randomness
uniform vec4  uColor;    // star hue (rgb, a = max alpha)
uniform float uCell;     // grid cell size in logical pixels

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73) + uSeed * 0.618);
  p += dot(p, p + 23.45);
  return fract(p.x * p.y);
}

void main() {
  vec2 grid = FlutterFragCoord().xy / uCell;
  vec2 cell = floor(grid);
  vec2 local = fract(grid) - 0.5;

  float r1 = hash(cell);
  float r2 = hash(cell + vec2(17.17, 9.31));
  float r3 = hash(cell + vec2(3.77, 41.13));

  // Staggered liftoff: each particle leaves in its own time window.
  float t = clamp((uProgress - r3 * 0.45) / 0.55, 0.0, 1.0);

  // Dust materializes only as the dissolution begins, and a mote that
  // finished its journey is gone for good.
  float materialize = smoothstep(0.0, 0.12, uProgress);
  if (materialize <= 0.0 || t >= 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Rest position inside the cell, then dispersion: outward from the
  // field center with a curl, drifting slightly upward like warmth.
  vec2 origin = (vec2(r1, r2) - 0.5) * 0.6;
  vec2 center = (cell + 0.5) * uCell / uSize - 0.5;
  vec2 radial = normalize(center + vec2(1e-4, 1e-4));
  vec2 curl = vec2(-radial.y, radial.x) * (r1 - 0.5) * 0.7;
  vec2 pos = origin + (radial + curl + vec2(0.0, -0.4)) * t * t * (0.3 + r2);

  float d = distance(local, pos);
  float radius = (0.05 + 0.09 * r2) * (1.0 - 0.55 * t);
  float core = smoothstep(radius, 0.0, d);
  float shimmer = 0.7 + 0.3 * sin(uSeed * 6.2831 + r1 * 40.0);
  float alpha = core * shimmer * pow(1.0 - t, 1.6) * materialize;

  // A few embers burn brighter than the rest of the dust.
  vec3 tint = mix(uColor.rgb, vec3(1.0), step(0.94, r1));
  fragColor = vec4(tint, uColor.a * alpha);
}

#pragma language glsl3

uniform float stepsize;
uniform vec2 aspect;

#define EPS .001

vec4 effect(vec4 c, Image tex, vec2 tc, vec2 sc) {
    vec4 nearestSeed = vec4(-2.0);
    float nearestDist = 1000.0;
    vec2 size = textureSize(tex, 0);

    vec2 aspect = vec2(size.x/size.y, 1.0);

    for (float y = -1.0; y <= 1.0; y += 1.0) {
        for (float x = -1.0; x <= 1.0; x += 1.0) {

            vec2 sampleUV = tc + vec2(x, y) * aspect.xy * stepsize;

            if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) { continue; }

            vec4 sampleValue = (texture(tex, sampleUV)*c);
            vec2 sampleSeed = sampleValue.xy;
            bvec2 all = equal(sampleValue.xy, vec2(0.0));
  
            if (sampleSeed.x != 0.0 && sampleSeed.y != 0.0) {
                vec2 diff = sampleSeed - tc;
                float dist = dot(diff,diff);
                if (dist < nearestDist) {
                    nearestDist = dist;
                    nearestSeed = sampleValue;
                }
            }
        }
    }

    return vec4(nearestSeed.xy, 0.0, 1.0);
}

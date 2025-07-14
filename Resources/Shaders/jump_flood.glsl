uniform float stepsize;
uniform vec2 aspect;
uniform vec2 size;

#define EPS .001

vec4 effect(vec4 c, Image tex, vec2 tc, vec2 sc) {
    vec4 nearestSeed = vec4(0.0);
    float nearestDist = 1.0;

    for (float y = -1.0; y <= 1.0; y += 1.0) {
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            vec2 sampleUV = tc + vec2(x, y) * aspect.yx * stepsize;

            vec4 sampleValue = (Texel(tex, sampleUV)*c);
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

    return nearestSeed;
}

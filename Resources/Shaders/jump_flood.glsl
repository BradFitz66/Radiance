uniform float stepsize;
uniform vec2 oneOverSize;
uniform vec2 aspect;


#define EPS .001
#define IsSeed (x) (x.x > EPS && x.y > EPS)


vec4 effect(vec4 c, Image tex, vec2 tc, vec2 sc) {
    vec4 nearestSeed = vec4(0.0);
    float nearestDist = 9999;

    for (float y = -1.0; y <= 1.0; y += 1.0) {
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            vec2 sampleUV = tc + vec2(x, y) * stepsize * oneOverSize.xy;


            vec4 sampleValue = Texel(tex, sampleUV);
            vec2 sampleSeed = sampleValue.xy;

            if (sampleValue.r > EPS || sampleValue.g > EPS) {
                vec2 diff = sampleSeed - tc;
                float dist = dot(diff, diff);
                if (dist < nearestDist) {
                    nearestDist = dist;
                    nearestSeed = sampleValue;
                }
            }
        }
    }

    return nearestSeed;
}

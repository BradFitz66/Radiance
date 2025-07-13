#ifdef GL_ES
precision mediump float;
#endif
uniform float rayCount;
uniform float time;
uniform float sunAngle;
uniform bool showNoise;
uniform bool showGrain;
uniform bool useTemporalAccum;
uniform bool enableSun;
uniform float maxSteps;

uniform Image lastFrameTexture;
uniform Image distanceTexture;

const float PI = 3.14159265;
const float TAU = 2.0 * PI;
const float ONE_OVER_TAU = 1.0 / TAU;
const float PAD_ANGLE = 0.01;
const float EPS = 0.001;

const vec3 skyColor = vec3(0.02, 0.08, 0.2);
const vec3 sunColor = vec3(1, 0.5, 0.5);
const float goldenAngle = PI * 0.7639320225;

// Popular rand function
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec3 sunAndSky(float rayAngle) {
    // Get the sun / ray relative angle
    float angleToSun = mod(rayAngle - sunAngle, TAU);
    
    // Sun falloff based on the angle
    float sunIntensity = smoothstep(1.0, 0.0, angleToSun);
    
    // And that's our sky radiance
    return sunColor * sunIntensity + skyColor;
}

bool outOfBounds(vec2 uv) {
  return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) {
    vec2 uv = tc;
    
    vec4 light = Texel(t, uv)*c;

    vec4 radiance = vec4(0.0);

    float oneOverRayCount = 1.0 / float(rayCount);
    float angleStepSize = TAU * oneOverRayCount;
    
    float coef = useTemporalAccum ? time : 0.0;
    float offset = showNoise ? rand(uv + coef) : 0.0;
    float rayAngleStepSize = showGrain ? angleStepSize + offset * TAU : angleStepSize;
    
    // Not light source or occluder
    if (light.a < 0.1) {    
        // Shoot rays in "rayCount" directions, equally spaced, with some randomness.
        for(int i = 0; i < rayCount; i++) {
            float angle = rayAngleStepSize * (float(i) + offset) + sunAngle;
            vec2 rayDirection = vec2(cos(angle), -sin(angle));
            
            vec2 sampleUv = uv;
            vec4 radDelta = vec4(0.0);
            bool hitSurface = false;
            
            // We tested uv already (we know we aren't an object), so skip step 0.
            for (int step = 1; step < maxSteps; step++) {
                // How far away is the nearest object?
                float dist = Texel(distanceTexture, sampleUv).r;
                
                // Go the direction we're traveling (with noise)
                sampleUv += rayDirection * dist;
                
                if (outOfBounds(sampleUv)) break;
                
                if (dist < EPS) {
                  vec4 sampleColor = Texel(t, sampleUv);
                  radDelta += sampleColor;
                  hitSurface = true;
                  break;
                }
            }

            // If we didn't find an object, add some sky + sun color
            if (!hitSurface && enableSun) {
              radDelta += vec4(sunAndSky(angle), 1.0);
            }

            // Accumulate total radiance
            radiance += radDelta;
        }
    } else if (length(light.rgb) >= 0.1) {
        radiance = light;
    }


    // Bring up all the values to have an alpha of 1.0.
    vec4 finalRadiance = vec4(max(light, radiance * oneOverRayCount).rgb, 1.0);
    if (useTemporalAccum && time > 0.0) {
      vec4 prevRadiance = Texel(lastFrameTexture, tc);
      return mix(finalRadiance, prevRadiance, 0.9);
    } else {
      return finalRadiance;
    }
}
vec4 effect(vec4 c, Image tex, vec2 tc, vec2 sc) {
    vec2 jf = (Texel(tex, tc)).xy;
    float dist = clamp(distance(tc,jf),0.0,1.0);

    return vec4(dist, 0.0, 0.0, 1.0);
}
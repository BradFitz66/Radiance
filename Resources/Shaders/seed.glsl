vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) {
    float alpha = (Texel(t, tc)).a;
    return vec4(alpha*tc, 0.0, 1.0);
}
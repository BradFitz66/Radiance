#pragma language glsl3
uniform float threshold = 2;
const float offset_1 = 1.5;
const float offset_2 = 3.5;

const float alpha_0 = 0.23;
const float alpha_1 = 0.32;
const float alpha_2 = 0.07;

float luminance(vec3 color)
{
    // numbers make 'true grey' on most monitors, apparently
    return ((0.212671 * color.r) + (0.715160 * color.g) + (0.072169 * color.b));
}

vec4 effect(vec4 color, Image t, vec2 texture_coords, vec2 pixel_coords)
{
    vec2 size = textureSize(t,0);
    
    float canvas_w = size.x;
    float canvas_h = size.y;

    vec4 texcolor = Texel(t, texture_coords);


    // Vertical blur
    vec3 tc_v = texcolor.rgb * alpha_0;

    tc_v += Texel(t, texture_coords + vec2(0.0, offset_1) / canvas_h).rgb * alpha_1;
    tc_v += Texel(t, texture_coords - vec2(0.0, offset_1) / canvas_h).rgb * alpha_1;

    tc_v += Texel(t, texture_coords + vec2(0.0, offset_2) / canvas_h).rgb * alpha_2;
    tc_v += Texel(t, texture_coords - vec2(0.0, offset_2) / canvas_h).rgb * alpha_2;

    // Horizontal blur
    vec3 tc_h = texcolor.rgb * alpha_0;

    tc_h += Texel(t, texture_coords + vec2(offset_1, 0.0) / canvas_w).rgb * alpha_1;
    tc_h += Texel(t, texture_coords - vec2(offset_1, 0.0) / canvas_w).rgb * alpha_1;

    tc_h += Texel(t, texture_coords + vec2(offset_2, 0.0) / canvas_w).rgb * alpha_2;
    tc_h += Texel(t, texture_coords - vec2(offset_2, 0.0) / canvas_w).rgb * alpha_2;

    // Smooth
    vec3 extract = smoothstep(threshold * 0.7, threshold, luminance(texcolor.rgb)) * texcolor.rgb;
    return vec4(extract + tc_v * 0.8 + tc_h * 0.8, 1.0);
}

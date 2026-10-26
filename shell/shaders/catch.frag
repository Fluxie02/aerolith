#version 440
#extension GL_GOOGLE_include_directive : require
#include "material.glsl"
void main() {
    vec2 p = qt_TexCoord0;
    float across = u.parameters.x > .5 ? p.x : p.y;
    float along = u.parameters.x > .5 ? p.y : p.x;
    float lip = smoothstep(.46,.82,across);
    float catchLight = (1.0-smoothstep(.0,.34,across)) * (1.0-smoothstep(.15,.85,along));
    // Never extend the luminous footprint. Reduced mode caps the catch at .07.
    float amplitude = u.policy.x < 1.5 ? .07 : .18;
    vec3 colour = mix(u.accent.rgb, u.surface2.rgb, lip * .55);
    colour = mix(colour, u.text.rgb, catchLight * amplitude);
    finish(colour, .72);
}

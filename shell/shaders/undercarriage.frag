#version 440
#extension GL_GOOGLE_include_directive : require
#include "material.glsl"
void main() {
    // Only narrow exposed right/bottom strips are drawn. No bay-sized pass.
    float across = u.parameters.x > .5 ? qt_TexCoord0.x : qt_TexCoord0.y;
    float recess = smoothstep(.0,.65,across);
    vec3 colour = mix(u.bg.rgb, u.surface2.rgb, .15 + .85 * recess);
    float lip = smoothstep(.86,.95,across) * (1.0-smoothstep(.95,1.0,across));
    colour = mix(colour,u.grid.rgb,lip * .40);
    finish(colour, 1.0);
}

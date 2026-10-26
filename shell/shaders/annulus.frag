#version 440
#extension GL_GOOGLE_include_directive : require
#include "material.glsl"
void main() {
    vec2 p = (qt_TexCoord0 - .5) * u.metrics.xy;
    float r = u.parameters.x;
    float d = length(p);
    float aa = 1.0 / u.metrics.w;
    float inner = abs(d - r * .91);
    float outer = abs(d - r);
    float band = min(inner, outer);
    float mask = 1.0 - smoothstep(1.0*u.metrics.z, 2.5*u.metrics.z+aa, band);
    // Opposite lips expose a recess; the middle stays completely unshaded.
    float light = .5 + .5 * dot(p / max(d,1.0), normalize(vec2(-.6,-.8)));
    vec3 colour = mix(u.bg.rgb, u.grid.rgb, .12 + .70 * light);
    vec2 index = vec2(cos(u.parameters.y), sin(u.parameters.y));
    float registration = pow(max(0.0, dot(p / max(d,1.0),index)), 160.0);
    colour = mix(colour, u.signal.rgb, registration * .48 * u.parameters.z);
    finish(colour, mask * .85);
}

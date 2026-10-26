#version 440
#extension GL_GOOGLE_include_directive : require
#include "material.glsl"
void main() {
    vec2 p = qt_TexCoord0;
    float base = min(min(edge(p,vec2(.08,.08),vec2(.62,.01)),edge(p,vec2(.62,.01),vec2(.97,.82))),
        min(edge(p,vec2(.97,.82),vec2(.75,.99)),min(edge(p,vec2(.75,.99),vec2(.25,.85)),edge(p,vec2(.25,.85),vec2(.08,.08)))));
    float side = quad(p,vec2(.08,.08),vec2(.25,.02),vec2(.79,.82),vec2(.25,.85));
    // The small lower triangle continues the opposed side skin.
    float lower = triangle(p,vec2(.25,.85),vec2(.79,.82),vec2(.75,.99));
    float face = quad(p,vec2(.25,.02),vec2(.62,.01),vec2(.97,.82),vec2(.79,.82));
    float toe = triangle(p,vec2(.79,.82),vec2(.97,.82),vec2(.75,.99));
    float mask = smoothstep(-.5/u.metrics.w,.5/u.metrics.w,base);
    vec3 skin = mix(u.surface2.rgb, u.bg.rgb, .18 + .42 * p.x);
    vec3 leading = mix(u.surface2.rgb, u.surface.rgb, .18 + .70 * p.x);
    // A restrained reflection follows the leading bevel, under its engraving.
    float seam = 1.0 - smoothstep(0.0, .07, abs(p.x - (.25 + .54 * clamp((p.y-.02)/.80,0.0,1.0))));
    leading = mix(leading, u.accent.rgb, seam * (u.parameters.x < .5 ? .12 : .035));
    vec3 colour = mix(u.bg.rgb, skin, max(side,lower));
    colour = mix(colour, leading, face);
    colour = mix(colour, u.bg.rgb, toe * .80);
    finish(colour, mask);
}

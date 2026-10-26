// Shared E02 interface; colours are supplied by Theme, never baked here.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 bg;
    vec4 surface;
    vec4 surface2;
    vec4 grid;
    vec4 signal;
    vec4 appLink;
    vec4 text;
    vec4 textDim;
    vec4 caution;
    vec4 critical;
    vec4 nominal;
    vec4 accent;
    vec4 metrics; // logical width/height, design unit, output pixel ratio
    vec4 policy; // motion mode, intensity, direction, quality
    vec4 parameters;
    float strength;
} u;

// Half-plane distance in logical pixels. The vertices follow the native
// clockwise screen-space polygons, so AA stays one physical pixel wide.
float edge(vec2 p, vec2 a, vec2 b) {
    vec2 v = (b - a) * u.metrics.xy;
    vec2 q = (p - a) * u.metrics.xy;
    return (v.x * q.y - v.y * q.x) / max(length(v), 0.001);
}
float quad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
    float dist = min(min(edge(p,a,b), edge(p,b,c)), min(edge(p,c,d), edge(p,d,a)));
    return smoothstep(-0.5 / u.metrics.w, 0.5 / u.metrics.w, dist);
}
float triangle(vec2 p, vec2 a, vec2 b, vec2 c) {
    float dist = min(edge(p,a,b), min(edge(p,b,c), edge(p,c,a)));
    return smoothstep(-0.5 / u.metrics.w, 0.5 / u.metrics.w, dist);
}
void finish(vec3 colour, float alpha) {
    float a = clamp(alpha * u.strength, 0.0, 1.0) * u.qt_Opacity;
    fragColor = vec4(colour * a, a);
}

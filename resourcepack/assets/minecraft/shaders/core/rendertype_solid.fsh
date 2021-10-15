#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;
in float face;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    float dir = 0.0;
    if (abs(normal.x) > 0.999) {
        dir = 1.0;
    } else if (abs(normal.z) > 0.999) {
        dir = 2.0;
    }
    fragColor.a = (round(max(smoothstep(5.0 / 15.0, 1.0, texCoord2.x), 1.0 - smoothstep(5.0 / 15.0, 12.0 / 15.0, texCoord2.y)) * 63.0) + dir * 64.0) / 255.0;
}

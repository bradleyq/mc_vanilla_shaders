#version 330
#define FSH

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in vec2 texCoord0;
in float vertexDistance;
in vec4 vertexColor;
in vec3 normal;

out vec4 fragColor;

void main() {
    vec2 oneTexel = 0.15 / textureSize(Sampler0, 0);
    vec4 color = texture(Sampler0, texCoord0);
    //  + texture(Sampler0, texCoord0 + vec2(oneTexel.x, 0.0)) + texture(Sampler0, texCoord0 + vec2(-oneTexel.x, 0.0))
    //  + texture(Sampler0, texCoord0 + vec2(0.0, oneTexel.y)) + texture(Sampler0, texCoord0 + vec2(0.0, -oneTexel.y));
    // color /= 4.0;
    color *= vertexColor * ColorModulator;
    // color.rgb *= normal * 0.5 + 0.5;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
}

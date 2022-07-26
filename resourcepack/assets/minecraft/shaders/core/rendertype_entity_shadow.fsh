#version 330
#define FSH

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;

in vec4 vertexColor;
in vec2 texCoord0;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discard;
    // discardControlGLPos(gl_FragCoord.xy, glpos);
    // vec4 outColor = texture(Sampler0, clamp(texCoord0, 0.0, 1.0));
    // outColor *= vertexColor * ColorModulator;
    // fragColor = outColor;
}

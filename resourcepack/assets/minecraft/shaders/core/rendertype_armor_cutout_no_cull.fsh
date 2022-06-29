#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform mat4 ProjMat;
uniform sampler2D Sampler0;
uniform sampler2D Sampler1;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec4 vertexColor;
in vec4 baseColor;
in vec2 texCoord0;
in vec2 texCoord1;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);

    if (!gui && !hand) {
        discardControlGLPos(gl_FragCoord.xy, glpos);
    }

    vec4 outColor = texture(Sampler0, texCoord0) * baseColor * ColorModulator;

    if (outColor.a < 0.1) {
        discard;
    }
    
    if (!gui && !hand) {
        outColor = getOutColor(outColor, vertexColor, texCoord2, gl_FragCoord.xy, getDirE(normal));
    }

    fragColor = outColor;
}

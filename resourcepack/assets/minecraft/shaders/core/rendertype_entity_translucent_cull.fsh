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
in vec2 texCoord0;
in vec2 texCoord1;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    if (!isGUI(ProjMat)) discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = linear_fog(color, vertexDistance, FogStart, FogEnd, FogColor);
    if (!isGUI(ProjMat)) {
        // fragColor.r = 1.0;
        // fragColor.gb *= vec2(0.5);
        fragColor.rgb *= fragColor.a;
        fragColor.a = 1.0;//(round(max(smoothstep(5.0 / 15.0, 1.0, texCoord2.x), 1.0 - smoothstep(5.0 / 15.0, 12.0 / 15.0, texCoord2.y)) * 63.0) * 4.0 + getDirE(normal)) / 255.0;
    }//TODO: figure this shiet out
}

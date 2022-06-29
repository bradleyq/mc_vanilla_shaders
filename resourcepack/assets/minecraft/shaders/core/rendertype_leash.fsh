#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in float vertexDistance;
in vec2 texCoord2;
flat in vec4 vertexColor;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = vertexColor;
    outColor.a = 1.0;
    outColor = getOutColorT(vertexColor, vec4(1.0), texCoord2, gl_FragCoord.xy, FACETYPE_Y, PBRTYPE_STANDARD);
    fragColor = outColor;
}

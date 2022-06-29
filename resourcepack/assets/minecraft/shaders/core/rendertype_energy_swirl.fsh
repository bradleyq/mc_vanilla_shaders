#version 150

#moj_import <utils.glsl>

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec2 texCoord0;
in vec4 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (outColor.a < 0.1 || (int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 0) {
        discard;
    }

    outColor.a = outColor.b;
    outColor = getOutColorT(outColor, vec4(0.0), vec2(0.0), gl_FragCoord.xy, FACETYPE_S, PBRTYPE_TEMISSIVE);
    outColor.a = 1.0;
    fragColor = outColor;
}
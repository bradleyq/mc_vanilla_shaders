#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec2 texCoord0;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = texture(Sampler0, texCoord0);
    
    if (outColor.a < 0.1 || (int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 1) {
        discard;
    }

    outColor *= vertexColor * ColorModulator;
    outColor.a = (1.0 - outColor.r) * 0.75;
    outColor.rgb = vec3(0.0);
    outColor = getOutColorT(outColor, vec4(0.0), vec2(0.0), gl_FragCoord.xy, FACETYPE_S, PBRTYPE_TRANSLUCENT);
    fragColor = outColor;
}

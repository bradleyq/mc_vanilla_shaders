#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec4 baseColor;
in vec4 vertexColor;
in vec2 texCoord2;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = baseColor;
    outColor *= ColorModulator;

    if (outColor.a < 0.1 || (outColor.a < 254.5 / 255.0 && (int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 1)) {
        discard;
    }

    if (outColor.a < 254.5 / 255.0) {
        outColor = getOutColorT(outColor * vertexColor, vec4(0.0), vec2(0.0), gl_FragCoord.xy, FACETYPE_S, PBRTYPE_TRANSLUCENT);
        outColor.a = 1.0;
    }
    else {
        outColor.a = 1.0;
        outColor = getOutColorSTDALock(outColor, vertexColor, texCoord2, gl_FragCoord.xy);
    }
    
    fragColor = outColor;
}

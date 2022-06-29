#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform sampler2D Sampler0;
uniform mat4 ProjMat;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in vec4 vertexColor;
in vec4 baseColor;
in vec4 overlayColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec4 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);
    
    if (!gui && !hand) {
        discardControlGLPos(gl_FragCoord.xy, glpos);
    }

    vec4 outColor = texture(Sampler0, texCoord0);

    if (outColor.a < 0.1 || (!gui && !hand && outColor.a < 254.5 / 255.0 && (int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 0)) {
        discard;
    }

    outColor *= baseColor * ColorModulator;
    outColor.rgb = mix(overlayColor.rgb, outColor.rgb, overlayColor.a);

    if (!gui && !hand) {
        if (outColor.a < 254.5 / 255.0) {
            outColor = getOutColorT(outColor, vec4(0.0), vec2(0.0), gl_FragCoord.xy, FACETYPE_S, PBRTYPE_TRANSLUCENT);
            outColor.a = 1.0;
        }
        else {
            outColor.a = 1.0;
            outColor = getOutColorSTDALock(outColor, vertexColor, texCoord2, gl_FragCoord.xy);
        }
    }
    
    fragColor = outColor;
}
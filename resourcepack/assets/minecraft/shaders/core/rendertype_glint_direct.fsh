#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform mat4 ProjMat;
uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;

in float vertexDistance;
in vec2 texCoord0;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);

    vec4 outColor = texture(Sampler0, texCoord0) * ColorModulator;
    
    if (outColor.a < 0.1) {
        discard;
    }

    outColor.rgb *= 0.5;

    if (!gui && !hand) {
        // outColor.rgb *= 0.5;
        outColor = getOutColorSTDALock(outColor, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        outColor.gb = vec2(clamp(outColor.g - 0.5, 0.0, 0.5), 0.0);
    } 

    fragColor = outColor;
}

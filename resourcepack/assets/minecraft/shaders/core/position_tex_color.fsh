#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform vec2 ScreenSize;
uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

in vec2 texCoord0;
in vec4 vertexColor;
in mat4 modelMat;

out vec4 fragColor;

void main() {
    vec4 outColor = texture(Sampler0, texCoord0);
    int index = inControl(gl_FragCoord.xy, ScreenSize.x);
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);

    if (outColor.a < 0.1 && (index == -1 || gui || hand)) {
        discard;
    }

    outColor *= vertexColor * ColorModulator;

    if (!gui && !hand) {
        if (index != -1) {

            // store ProjMat in control pixels
            if (index >= 5 && index <= 15) {
                int c = (index - 5) / 4;
                int r = (index - 5) - c * 4;
                c = (c == 0 && r == 1) ? c : c + 1;
                outColor = vec4(encodeFloat(ProjMat[c][r]), 1.0);
            }

            // store ModelViewMat in control pixels
            else if (index >= 16 && index <= 24) {
                int c = (index - 16) / 3;
                int r = (index - 16) - c * 3;
                outColor = vec4(encodeFloat(modelMat[c][r]), 1.0);
            }

            // store ProjMat[0][0] and ProjMat[1][1] in control pixels
            else if (index >= 3 && index <= 4) {
                outColor = vec4(encodeFloat(atan(ProjMat[index - 3][index - 3])), 1.0);
            } 

            // store FogColor in control pixels
            else if (index == 25) {
                outColor = vec4(FogColor.rgb, 1.0);
            } 

            // store FogStart
            else if (index == 26) {
                outColor = vec4(encodeInt(int(round(FogStart))), 1.0);
            }

            // store FogEnd
            else if (index == 27) {
                outColor = vec4(encodeInt(int(round(FogEnd))), 1.0);
            } 
            
            // store Dimension
            else if (index == 28) {
                outColor = vec4(vec3(float(DIM_END) / 255.0), 1.0);
            }

            // blackout control pixels for sunDir so sun can write to them (by default, all pixels are FogColor)
            else {
                outColor = vec4(0.0, 0.0, 0.0, 1.0);
            }
        }
        else {
            outColor.a = 1.0;
            outColor = getOutColorSTDALock(outColor, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        } 
    } 

    fragColor = outColor;
}

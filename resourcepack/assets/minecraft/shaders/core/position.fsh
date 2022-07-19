#version 150

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;
uniform vec2 ScreenSize;
uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

in mat4 ProjInv;
in float isSky;
in float vertexDistance;

out vec4 fragColor;

// at this point, the entire sky is drawable: isSky for sky, stars and void plane for everything else.
// similar logic can be added in vsh to separate void plane from stars.
void main() {
    int index = inControl(gl_FragCoord.xy, ScreenSize.x);
    if (index != -1) {
        if (isSky > 0.5) {
            // store ProjMat in control pixels
            if (index >= 5 && index <= 15) {
                int c = (index - 5) / 4;
                int r = (index - 5) - c * 4;
                c = (c == 0 && r == 1) ? c : c + 1;
                fragColor = vec4(encodeFloat(ProjMat[c][r]), 1.0);
            }
            // store ModelViewMat in control pixels
            else if (index >= 16 && index <= 24) {
                int c = (index - 16) / 3;
                int r = (index - 16) - c * 3;
                fragColor = vec4(encodeFloat(ModelViewMat[c][r]), 1.0);
            }
            // store ProjMat[0][0] and ProjMat[1][1] in control pixels
            else if (index >= 3 && index <= 4) {
                fragColor = vec4(encodeFloat(atan(ProjMat[index - 3][index - 3])), 1.0);
            }  
            // store FogColor in control pixels
            else if (index == 25) {
                fragColor = FogColor;
            } 
            else if (index == 26) {
                fragColor = vec4(vec3(float(FogStart < 0.0)), 1.0);
            }
            // blackout control pixels for sunDir so sun can write to them (by default, all pixels are FogColor)
            else {
                fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            }
        } else {
            discard;
        }
    }

    // not a control pixel, draw sky like normal
    else if (isSky > 0.5) {
        vec4 screenPos = gl_FragCoord;
        screenPos.xy = (screenPos.xy / ScreenSize - vec2(0.5)) * 2.0;
        screenPos.zw = vec2(1.0);
        vec3 view = normalize((ProjInv * screenPos).xyz);
        float ndusq = clamp(dot(view, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
        ndusq = ndusq * ndusq;

        fragColor = linear_fog(ColorModulator, pow(1.0 - ndusq, 8.0), 0.0, 1.0, FogColor);
    }
    else {
        fragColor = linear_fog(ColorModulator, vertexDistance, FogStart, FogEnd, FogColor);
    }

}

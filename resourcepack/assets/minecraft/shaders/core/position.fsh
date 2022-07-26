#version 330
#define FSH

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
in float seed;
in vec2 uv;

out vec4 fragColor;

int xorshift(int value) {
    // Xorshift*32
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

float PRNG(int seed) {
    seed = xorshift(seed);
    return abs(fract(float(seed) / 3141.592653));
}



// at this point, the entire sky is drawable: isSky for sky, stars and void plane for everything else.
// similar logic can be added in vsh to separate void plane from stars.
void main() {
    bool gui = isGUI(ProjMat);

    if (!gui) {

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
                    fragColor = vec4(FogColor.rgb, 1.0);
                } 

                // store FogStart
                else if (index == 26) {
                    fragColor = vec4(encodeInt(int(round(FogStart))), 1.0);
                }

                // store FogEnd
                else if (index == 27) {
                    fragColor = vec4(encodeInt(int(round(FogEnd))), 1.0);
                } 

                // store Dimension
                else if (index == 28) {
                    fragColor = vec4(vec3(float(DIM_OVER) / 255.0), 1.0);
                }

                // blackout control pixels for sunDir so sun can write to them (by default, all pixels are FogColor)
                else {
                    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
                }
            } 
            else {
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
            // ndusq = ndusq * ndusq;
            vec4 skycol = ColorModulator;
            vec3 noise = vec3(PRNG(int(gl_FragCoord.x) + int(gl_FragCoord.y) * int(ScreenSize.x))) * 0.01;
            skycol.rgb += (1.0 - length(skycol.rgb)) * (vec3(0.02, 0.04, 0.06));
            vec4 fc = FogColor;
            fc.rgb += (1.0 - length(skycol.rgb)) * (vec3(0.01, 0.04, 0.03));
            fc.rgb += noise;
            skycol = linear_fog_real(skycol, pow(1.0 - ndusq, 4.0), 0.0, 1.0, fc);
            skycol.a = 1.0;
            fragColor = getOutColorSTDALock(skycol, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        }

        // draw stars with random colors
        else if (isSky < -0.5) {
            int s1 = int(seed);
            int s2 = xorshift(s1);
            int s3 = xorshift(s2);
            int s4 = xorshift(s3);
            vec4 starColor = ColorModulator * 1.4 + vec4(PRNG(s1) * 0.3, PRNG(s2) * 0.2, PRNG(s3) * 0.3, PRNG(s4) - 0.6);

            starColor = mix(starColor, vec4(starColor.rgb, 0.0), clamp(length(uv - vec2(0.5)) * 2.0, 0.0, 1.0));
            fragColor = getOutColorSTDALock(starColor, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        }
        else {
            fragColor = getOutColorSTDALock(linear_fog_real(ColorModulator, vertexDistance, FogStart, FogEnd, FogColor), vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        }
    }
    else {
        fragColor = linear_fog_real(ColorModulator, vertexDistance, FogStart, FogEnd, FogColor);
    }

}

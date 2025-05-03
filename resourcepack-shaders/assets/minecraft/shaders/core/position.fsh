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

out vec4 fragColor;

#define FOG_NIGHT_BOOST vec3(6.0 / 255.0, 7.0 / 255.0, 1.0 / 255.0)

// at this point, the entire sky is drawable: isSky for sky, stars and void plane for everything else.
// similar logic can be added in vsh to separate void plane from stars.
void main() {
    bool gui = isGUI(ProjMat);

    if (!gui) {

        int index = inControl(gl_FragCoord.xy, ScreenSize.x);
        if (index != -1) {
            if (isSky > 0.5) {

                // store ProjMat in control pixels
                if (index >= CTL_PMAT10 && index <= CTL_PMAT32) {
                    int c = (index - 5) / 4;
                    int r = (index - 5) - c * 4;
                    c = (c == 0 && r == 1) ? c : c + 1;
                    fragColor = vec4(encodeFloat(ProjMat[c][r]), 1.0);
                }

                // store ModelViewMat in control pixels
                else if (index >= CTL_MVMAT00 && index <= CTL_MVMAT22) {
                    int c = (index - 16) / 3;
                    int r = (index - 16) - c * 3;
                    fragColor = vec4(encodeFloat(ModelViewMat[c][r]), 1.0);
                }

                // store ProjMat[0][0] and ProjMat[1][1] in control pixels
                else if (index == CTL_ATAN_PMAT00 || index == CTL_ATAN_PMAT11) {
                    fragColor = vec4(encodeFloat(atan(ProjMat[index - 3][index - 3])), 1.0);
                } 

                // store FogColor in control pixels
                else if (index == CTL_FOGCOLOR) {
                    vec4 fc = FogColor;
                    fc.rgb += (1.0 - clamp(length(ColorModulator.rgb), 0.0, 1.0)) * FOG_NIGHT_BOOST;
                    fragColor = vec4(fc.rgb, 1.0);
                } 

                // store FogStart
                else if (index == CTL_FOGSTART) {
                    fragColor = vec4(encodeInt(int(round(FogStart))), 1.0);
                }

                // store FogEnd
                else if (index == CTL_FOGEND) {
                    fragColor = vec4(encodeInt(int(round(FogEnd))), 1.0);
                } 

                // store Dimension
                else if (index == CTL_DIM) {
                    fragColor = vec4(vec3(float(DIM_OVER) / 255.0), 1.0);
                }

                // store FarClip
                else if (index == CTL_FARCLIP) {
                    vec4 probe = inverse(ProjMat) * vec4(0.0, 0.0, 1.0, 1.0);
                    probe.xyz /= probe.w;
                    fragColor = vec4(encodeInt(int(round(length(probe.xyz)))), 1.0);
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
        // not a control pixel, draw nothing. Sky drawn in post.
        else {
            fragColor = getOutColorSTDALock(vec4(0.0, 0.0, 0.0, 1.0), vec4(1.0), vec2(0.0), gl_FragCoord.xy);
        }
    }
    else {
        fragColor = linear_fog_real(ColorModulator, vertexDistance, FogStart, FogEnd, FogColor);
    }

}

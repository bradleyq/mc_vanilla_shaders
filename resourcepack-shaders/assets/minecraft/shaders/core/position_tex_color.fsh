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
uniform mat3 IViewRotMat;
uniform mat4 ProjMat;
uniform float GameTime;

in vec2 texCoord0;
in vec4 vertexColor;
in mat4 modelMat;
in vec3 pos;

out vec4 fragColor;

// Auroras by nimitz 2017 (twitter: @stormoid) https://www.shadertoy.com/view/XtGGRt
#define AURORA_COLOR_BASE vec3(1.0, 0.3, 1.0)
#define AURORA_COLOR_TIP vec3(0.0, 1.0, 1.0)
#define AURORA_COLOR_BASE2 vec3(0.2, 0.0, 0.2)
#define AURORA_COLOR_TIP2 vec3(0.0, 0.2, 0.24)
#define AURORA_SPEED 40.0
#define AURORA_SPEED2 80.0
#define AURORA_SAMPLES 25
#define AURORA_INTENSITY 1.8

mat2 mm2(in float a) {
    float c = cos(a), s = sin(a);return mat2(c,s,-s,c);
}

mat2 m2 = mat2(0.95534, 0.29552, -0.29552, 0.95534);

float tri(in float x) {
    return clamp(abs(fract(x)-.5),0.01,0.49);
}

vec2 tri2(in vec2 p) {
    return vec2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));
}

float triNoise2d(in vec2 p, float spd) {
    float z = 1.8;
    float z2 = 2.5;
    float rz = 0.0;
    p *= mm2(p.x * 0.06);
    vec2 bp = p;
    for (float i = 0.0; i < 5.0; i++ ) {
        vec2 dg = tri2(bp * 1.85) * 0.75;
        dg *= mm2(GameTime * PI * spd);
        p -= dg / z2;

        bp *= 1.3;
        z2 *= 0.45;
        z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;
        
        rz += tri(p.x + tri(p.y)) * z;
        p *= -m2;
    }
    return clamp(1.0 / pow(rz * 29.0, 1.3),0.0, 0.55);
}

vec4 aurora(vec3 dir) {
    vec4 outColor = vec4(0);
    vec4 avgColor = vec4(0);
    
    for(int i = 0; i < AURORA_SAMPLES; i++) {
        float jitter = 0.012 * hash21(gl_FragCoord.xy) * smoothstep(0.0, 15.0, float(i));
        float height = ((0.8 + pow(float(i), 1.4) * 0.004)) / (dir.y * 2.0 + 0.4);
        height -= jitter;

        vec2 coord = (height * dir).zx;
        float pattern = triNoise2d(coord, AURORA_SPEED);
        vec4 interColor = vec4(0.0, 0.0, 0.0, pattern);

        interColor.rgb = mix(AURORA_COLOR_BASE, AURORA_COLOR_TIP, pow(float(i) / 25.0, 2.0)) * pattern;
        avgColor =  mix(avgColor, interColor, 0.5);
        outColor += avgColor * exp2(-float(i) * 0.065 - 2.5) * smoothstep(0.0, 5.0, float(i));
    }
    
    outColor *= (clamp(dir.y * 15.0 + 0.4, 0.0, 1.0));
    
    return outColor * AURORA_INTENSITY;
}

void main() {
    vec4 outColor = textureLod(Sampler0, texCoord0, -4);
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
            if (index >= CTL_PMAT10 && index <= CTL_PMAT32) {
                int c = (index - 5) / 4;
                int r = (index - 5) - c * 4;
                c = (c == 0 && r == 1) ? c : c + 1;
                outColor = vec4(encodeFloat(ProjMat[c][r]), 1.0);
            }

            // store ModelViewMat in control pixels
            else if (index >= CTL_MVMAT00 && index <= CTL_MVMAT22) {
                int c = (index - 16) / 3;
                int r = (index - 16) - c * 3;
                outColor = vec4(encodeFloat(modelMat[c][r]), 1.0);
            }

            // store ProjMat[0][0] and ProjMat[1][1] in control pixels
            else if (index == CTL_ATAN_PMAT00 || index == CTL_ATAN_PMAT11) {
                outColor = vec4(encodeFloat(atan(ProjMat[index - 3][index - 3])), 1.0);
            } 

            else if (index >= CTL_SUNDIRX && index <= CTL_SUNDIRZ) {
                vec4 sunDir = vec4(0.0, -1.0, 0.0, 0.0);
                outColor = vec4(encodeFloat(sunDir[index]), 1.0);
            }

            // store FogColor in control pixels
            else if (index == CTL_FOGCOLOR) {
                outColor = vec4(FogColor.rgb, 1.0);
            } 

            // store FogStart
            else if (index == CTL_FOGSTART) {
                outColor = vec4(encodeInt(int(round(FogStart))), 1.0);
            }

            // store FogEnd
            else if (index == CTL_FOGEND) {
                outColor = vec4(encodeInt(int(round(FogEnd))), 1.0);
            } 
            
            // store Dimension
            else if (index == CTL_DIM) {
                outColor = vec4(vec3(float(DIM_END) / 255.0), 1.0);
            }

            // store FarClip
            else if (index == CTL_FARCLIP) {
                vec4 probe = inverse(ProjMat) * vec4(0.0, 0.0, 1.0, 1.0);
                probe.xyz /= probe.w;
                outColor = vec4(encodeInt(int(round(length(probe.xyz)))), 1.0);
            }

            // blackout control pixels for sunDir so sun can write to them (by default, all pixels are FogColor)
            else {
                outColor = vec4(0.0, 0.0, 0.0, 1.0);
            }
        }
        else {
            outColor.a = 1.0;

            vec3 dir = normalize(pos);
        
            float fade = smoothstep(0.0, 0.1, abs(dir.y));
            
            if (dir.y > 0.0){
                vec4 aur = smoothstep(0.0, 1.5, aurora(dir)) * fade;
                outColor.rgb = outColor.rgb * (1.0 - aur.a) + aur.rgb;
            }
            else {
                outColor.rgb += mix(AURORA_COLOR_BASE2, AURORA_COLOR_TIP2, -dir.y) * triNoise2d(dir.xz, AURORA_SPEED2) * fade;
            }

            outColor = getOutColorSTDALock(outColor, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
            
        } 
    } 

    fragColor = outColor;
}

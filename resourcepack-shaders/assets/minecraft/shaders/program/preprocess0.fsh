#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D PrevDataSampler;
uniform sampler2D PrevMainSampler;
uniform sampler2D CurrCodedMainSampler;
uniform sampler2D CurrCodedMainSamplerDepth;

uniform vec2 InSize;
uniform vec2 AuxSize0;
uniform float FOVGuess;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define FPRECISION_L 400000.0
#define PROJNEAR 0.05
#define PROJFAR 1024.0
#define PI 3.14159265358979
#define FUDGE 32.0

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3
#define DIM_MAX 3

#define FOG_NETHER_GAIN vec3(0.14, 0.08, 0.02)
#define FOG_CAVE vec3(38.0 / 255.0, 38.0 / 255.0, 51.0 / 255.0)
#define FOG_DEFAULT_WATER vec3(25.0 / 255.0, 25.0 / 255.0, 255.0 / 255.0)
#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define FOG_WATER vec3(0.0 / 255.0, 38.0 / 255.0, 38.0 / 255.0)
#define FOG_WATER_FAR 72.0
#define FOG_END vec3(19.0 / 255.0, 16.0 / 255.0, 19.0 / 255.0)
#define FOG_LAVA vec3(153.0 / 255.0, 25.0 / 255.0, 0.0)
#define FOG_LAVA_FAR 2.0
#define FOG_SNOW vec3(159.0 / 255.0, 187.0 / 255.0, 200.0 / 255.0)
#define FOG_SNOW_FAR 2.0
#define FOG_BLIND vec3(0.0)
#define FOG_BLIND_FAR 5.0
#define FOG_DARKNESS vec3(0.0)
#define FOG_DARKNESS_FAR 15.0
#define FOG_DEFAULT_FAR 150.0
#define FOG_TARGET 0.2
#define FOG_DIST_MULT 3.5
#define FOG_DIST_OVERCAST_REDUCE 2.0

#define FLAG_UNDERWATER 1<<0

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define FACETYPE_Y 0
#define FACETYPE_X 1
#define FACETYPE_Z 2
#define FACETYPE_S 3

#define EXPOSURE_SAMPLES 7
#define EXPOSURE_RADIUS 0.25
#define EXPOSURE_BIG_PRIME 7507

#define AL_SAMPLES 8
#define AL_RADIUS 0.25
#define AL_BIG_PRIME 7507

const vec2 offsets[9] = vec2[9](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0), vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0));

const vec2 poissonDisk[64] = vec2[64](
    vec2(-0.613392, 0.617481), vec2(0.170019, -0.040254), vec2(-0.299417, 0.791925), vec2(0.645680, 0.493210), vec2(-0.651784, 0.717887), vec2(0.421003, 0.027070), vec2(-0.817194, -0.271096), vec2(-0.705374, -0.668203), 
    vec2(0.977050, -0.108615), vec2(0.063326, 0.142369), vec2(0.203528, 0.214331), vec2(-0.667531, 0.326090), vec2(-0.098422, -0.295755), vec2(-0.885922, 0.215369), vec2(0.566637, 0.605213), vec2(0.039766, -0.396100),
    vec2(0.751946, 0.453352), vec2(0.078707, -0.715323), vec2(-0.075838, -0.529344), vec2(0.724479, -0.580798), vec2(0.222999, -0.215125), vec2(-0.467574, -0.405438), vec2(-0.248268, -0.814753), vec2(0.354411, -0.887570),
    vec2(0.175817, 0.382366), vec2(0.487472, -0.063082), vec2(-0.084078, 0.898312), vec2(0.488876, -0.783441), vec2(0.470016, 0.217933), vec2(-0.696890, -0.549791), vec2(-0.149693, 0.605762), vec2(0.034211, 0.979980),
    vec2(0.503098, -0.308878), vec2(-0.016205, -0.872921), vec2(0.385784, -0.393902), vec2(-0.146886, -0.859249), vec2(0.643361, 0.164098), vec2(0.634388, -0.049471), vec2(-0.688894, 0.007843), vec2(0.464034, -0.188818),
    vec2(-0.440840, 0.137486), vec2(0.364483, 0.511704), vec2(0.034028, 0.325968), vec2(0.099094, -0.308023), vec2(0.693960, -0.366253), vec2(0.678884, -0.204688), vec2(0.001801, 0.780328), vec2(0.145177, -0.898984),
    vec2(0.062655, -0.611866), vec2(0.315226, -0.604297), vec2(-0.780145, 0.486251), vec2(-0.371868, 0.882138), vec2(0.200476, 0.494430), vec2(-0.494552, -0.711051), vec2(0.612476, 0.705252), vec2(-0.578845, -0.768792),
    vec2(-0.772454, -0.090976), vec2(0.504440, 0.372295), vec2(0.155736, 0.065157), vec2(0.391522, 0.849605), vec2(-0.620106, -0.328104), vec2(0.789239, -0.419965), vec2(-0.545396, 0.538133), vec2(-0.178564, -0.596057));

float linearizeDepth(float depth) {
    return (2.0 * PROJNEAR * PROJFAR) / (PROJFAR + PROJNEAR - depth * (PROJFAR - PROJNEAR));    
}

vec2 getControl(int index, vec2 screenSize) {
    return vec2(floor(screenSize.x / 4.0) * 2.0 + float(index) * 2.0 + 0.5, 0.5) / screenSize;
}

vec3 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 128;
    return vec3(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0);
}

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

vec3 encodeFloat(float f) {
    return encodeInt(int(f * FPRECISION));
}

float decodeFloat(vec3 vec) {
    return decodeInt(vec) / FPRECISION;
}

vec3 encodeFloatL(float f) {
    return encodeInt(int(f * FPRECISION_L));
}

float decodeFloatL(vec3 vec) {
    return decodeInt(vec) / FPRECISION_L;
}

vec4 decodeHDR_0(vec4 color) {
    int alpha = int(color.a * 255.0);
    return vec4(vec3(color.r + float((alpha >> 4) % 4), color.g + float((alpha >> 2) % 4), color.b + float(alpha % 4)) * float(alpha >> 6), 1.0);
}

vec4 encodeHDR_0(vec4 color) {
    color = clamp(color, 0.0, 12.0);
    int alpha = clamp(int((max(max(color.r, color.g), color.b) + 3.999) / 4.0), 1, 3);
    color.rgb /= float(alpha);
    vec3 colorFloor = clamp(floor(color.rgb), 0.0, 3.0);

    alpha = alpha << 2;
    alpha += int(colorFloor.r);
    alpha = alpha << 2;
    alpha += int(colorFloor.g);
    alpha = alpha << 2;
    alpha += int(colorFloor.b);

    return vec4(clamp(color.rgb - colorFloor, 0.0, 1.0), alpha / 255.0);
}


float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

/*
Control Map:

[0] sunDir.x
[1] sunDir.y
[2] sunDir.z
[3] arctan(ProjMat[0][0])
[4] arctan(ProjMat[1][1])
[5] ProjMat[1][0]
[6] ProjMat[0][1]
[7] ProjMat[1][2]
[8] ProjMat[1][3]
[9] ProjMat[2][0]
[10] ProjMat[2][1]
[11] ProjMat[2][2]
[12] ProjMat[2][3]
[13] ProjMat[3][0]
[14] ProjMat[3][1]
[15] ProjMat[3][2]
[16] ModelViewMat[0][0]
[17] ModelViewMat[0][1]
[18] ModelViewMat[0][2]
[19] ModelViewMat[1][0]
[20] ModelViewMat[1][1]
[21] ModelViewMat[1][2]
[22] ModelViewMat[2][0]
[23] ModelViewMat[2][1]
[24] ModelViewMat[2][2]
[25] FogColor
[26] FogStart -> Unused
[27] FogEnd -> FogLambda
[28] Dimension
[29] RainStrength
[30] MiscFlags bit0:underwater
[31]
*/

/*
Post Temporals:
[32] Exposure Sample 0
[33] Exposure Sample 1
[34] Exposure Sample 2
[35] Exposure Sample 3
[36] Exposure Sample 4
[37] Exposure Sample 5
[38] Exposure Sample 6
[39] Exposure Sample 7
[40] Exposure Sample 8
[41] Exposure Avg
[42] ApplyLight Sample 0
[43] ApplyLight Sample 1
[44] ApplyLight Sample 2
[45] ApplyLight Sample 3
[46] ApplyLight Sample 4
[47] ApplyLight Average
[48] Cave
*/

void main() {

    //simply decoding all the control data and constructing the sunDir, ProjMat, ModelViewMat
    vec4 outColor = vec4(0.0);
    vec2 start = getControl(0, InSize);
    vec2 startData = 0.5 / AuxSize0;
    vec2 inc = vec2(2.0 / InSize.x, 0.0);
    vec2 incData = vec2(1.0 / AuxSize0.x, 0.0);
    vec4 temp = texture(DiffuseSampler, start + 25.0 * inc);
    int index = int(gl_FragCoord.x);

    if (index >= 32) {
        if (index >= 32 && index <= 40) {
            vec2 offset = offsets[index - 32];
            float lum = 0.0;
            for (int i = 0; i < EXPOSURE_SAMPLES; i += 1) {
                lum += luma(decodeHDR_0(texture(PrevMainSampler, EXPOSURE_RADIUS * (offset + poissonDisk[i + (index - 32) * EXPOSURE_SAMPLES] * 0.75) + vec2(0.5))).rgb);
            }
            lum = lum / EXPOSURE_SAMPLES - 20.0; // Fixed point L only supports [-20, 20] so subtract 20
            outColor = vec4(encodeFloatL(clamp(lum, -20.0, 20.0)), 1.0); 
        }
        else if (index == 41) {
            float lum = decodeFloatL(texture(PrevDataSampler, startData + 32.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 33.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 34.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 35.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 36.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 37.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 38.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 39.0 * incData).rgb)
                      + decodeFloatL(texture(PrevDataSampler, startData + 40.0 * incData).rgb);

            lum /= 9.0;

            lum += 20.0 - 2.0; // convert from fixed point L to regular fixed point

            vec4 last = texture(PrevDataSampler, startData + 41.0 * incData);
            if (last.a == 1.0) {
                lum = mix(lum, decodeFloat(last.rgb), 0.98);
            }
            outColor = vec4(encodeFloat(clamp(lum, -2.0, 2.0)), 1.0);
        }
        if (index >= 42 && index <= 46) {
            vec2 offset = offsets[index - 42];
            float lightAvg = 0.0;
            for (int i = 0; i < AL_SAMPLES; i += 1) {
                vec2 coords = AL_RADIUS * (offset + poissonDisk[i + (index - 42) * AL_SAMPLES]) + vec2(0.5);
                float depth = texture(CurrCodedMainSamplerDepth, coords).r;
                if (linearizeDepth(depth) < PROJFAR - FUDGE) {
                    vec2 data = texture(CurrCodedMainSampler, coords).ba;
                    int face = int(data.y * 255.0) % 4;
                    int stype = int(data.x * 255.0) % 8;
                    float applyLight = clamp(float(int(data.y * 255.0) / 4) / 63.0, 0.0, 1.0);
                    if (face == FACETYPE_S && stype == PBRTYPE_STANDARD) {
                        applyLight = clamp(float(int(data.x * 255.0) / 16) / 15.0, 0.0, 1.0);
                    }
                    lightAvg += applyLight;
                }
            }
            lightAvg = lightAvg / AL_SAMPLES;
            outColor = vec4(encodeFloat(clamp(lightAvg, 0.0, 1.0)), 1.0);
        }
        else if (index == 47) {
            float al = decodeFloat(texture(PrevDataSampler, startData + 42.0 * incData).rgb)
                     + decodeFloat(texture(PrevDataSampler, startData + 43.0 * incData).rgb)
                     + decodeFloat(texture(PrevDataSampler, startData + 44.0 * incData).rgb)
                     + decodeFloat(texture(PrevDataSampler, startData + 45.0 * incData).rgb)
                     + decodeFloat(texture(PrevDataSampler, startData + 46.0 * incData).rgb);
            al /= 5.0;

            vec4 last = texture(PrevDataSampler, startData + 47.0 * incData);
            vec4 currflags = texture(PrevDataSampler, startData + 30.0 * incData);
            if (currflags.a == 1.0 && (int(currflags.r * 255.0) & FLAG_UNDERWATER) > 0) {
                al = decodeFloat(last.rgb);
            }
            else if (last.a == 1.0) {
                al = mix(al, decodeFloat(last.rgb), 0.992);
            }
            outColor = vec4(encodeFloat(clamp(al, 0.6, 1.0)), 1.0); // [0.6, 1.0] to reduce inertia for cave checks
        }
        else if (index == 48) {
            outColor = vec4(encodeFloat(smoothstep(3.0, 2.0, decodeFloat(texture(PrevDataSampler, startData + 41.0 * incData).rgb) + 2.0) 
                                      * smoothstep(0.8, 1.0, decodeFloat(texture(PrevDataSampler, startData + 47.0 * incData).rgb))), 
                            1.0);
        }
    }
    else if (temp.a < 1.0) {

        /* Basic Matricies as follows
        tanVFOV = tan(FOVGuess * PI / 180.0 / 2.0);
        tanHFOV = tanVFOV * InSize.x / InSize.y;
        ProjMat = mat4(tanHFOV, 0.0,     0.0,                                               0.0,
                       0.0,     tanVFOV, 0.0,                                               0.0,
                       0.0,     0.0,    -(PROJFAR + PROJNEAR) / (PROJFAR - PROJNEAR),      -1.0,
                       0.0,     0.0,    -2.0 * (PROJFAR * PROJNEAR) / (PROJFAR - PROJNEAR), 0.0);
        ModelViewMat = mat4(1.0);
        */
        if (index == 0 || index == 2) {
            outColor = vec4(encodeFloat(0.0), 0.0);
        }
        else if (index == 1) {
            outColor = vec4(encodeFloat(-1.0), 0.0);
        }
        else if (index == 3) {
            outColor = vec4(encodeFloat(FOVGuess * PI / 180.0 / 2.0), 0.0);
        }
        else if (index == 4) {
            outColor = vec4(encodeFloat(atan(tan(FOVGuess * PI / 180.0 / 2.0) * InSize.x / InSize.y)), 0.0);
        }
        else if (index == 11) {
            outColor = vec4(encodeFloat(-(PROJFAR + PROJNEAR) / (PROJFAR - PROJNEAR)), 0.0);
        }
        else if (index == 12) {
            outColor = vec4(encodeFloat(-1.0), 0.0);
        }
        else if (index == 15) {
            outColor = vec4(encodeFloat(-2.0 * (PROJFAR * PROJNEAR) / (PROJFAR - PROJNEAR)), 0.0);
        }
        else if (index == 16 || index == 20 || index == 24) {
            outColor = vec4(encodeFloat(1.0), 0.0);
        }
        // fog color
        else if (index == 25) {
            vec4 dimtmp = texture(PrevDataSampler, startData + 28.0 * incData);
            float dim = DIM_UNKNOWN;
            if (dimtmp.a == 1.0) {
                dim = int(dimtmp.r * 255.0);
            }

            vec4 flagtmp = texture(PrevDataSampler, startData + 30.0 * incData);
            int flags = 0;
            if (flagtmp.a == 1.0) {
                flags = int(flagtmp.r * 255.0);
            }

            if (((dim == DIM_UNKNOWN || dim == DIM_END) && temp.b > 0.2) || (dim == DIM_NETHER && temp.b > temp.g * 9.0)) {
                temp.rgb = mix(FOG_WATER, temp.rgb, smoothstep(0.0, 0.05, length(temp.rgb / temp.b - FOG_DEFAULT_WATER)));
            }
            else {
                float lava = smoothstep(0.0, 0.05, length(temp.rgb - FOG_LAVA));
                float snow = smoothstep(0.0, 0.05, length(temp.rgb - FOG_SNOW));
                float blind = smoothstep(0.0, 0.05, length(temp.rgb - FOG_DARKNESS));
                float cave = decodeFloat(texture(PrevDataSampler, startData + 48.0 * incData).rgb);

                if (dim == DIM_NETHER) {
                    temp.rgb += FOG_NETHER_GAIN * lava * snow * blind;
                }
                else if (dim == DIM_OVER) {
                    if (lava > 0.5 && snow > 0.5 && blind > 0.5) {
                        temp.rgb = FOG_BLIND; // only case for this is transition from blind to not.
                    }
                }
            }
            outColor = temp;
        }
        else if (index == 26) {
            outColor = vec4(encodeInt(0), 0.0);
        }
        else if (index == 27) {
            float range = FOG_DEFAULT_FAR;
            float lava = smoothstep(0.05, 0.0, length(temp.rgb - FOG_LAVA));
            range = mix(range, FOG_LAVA_FAR, lava);
            float snow = smoothstep(0.05, 0.0, length(temp.rgb - FOG_SNOW));
            range = mix(range, FOG_SNOW_FAR, snow);
            float blind = smoothstep(0.05, 0.0, length(temp.rgb - FOG_DARKNESS));
            range = mix(range, FOG_DARKNESS_FAR, blind);
            outColor = vec4(encodeFloat(log(FOG_TARGET) / float(-range)), 0.0);
        }
        else if (index == 28) {
            outColor = texture(PrevDataSampler, startData + 28.0 * incData);
            if(outColor.a != 1.0 || int(outColor.r * 255.0) > DIM_MAX || outColor.r == 0.0) {
                vec4 dimtmp = texture(DiffuseSampler, start + 28.0 * inc);
                if (dimtmp.a == 1.0) {
                    outColor = dimtmp;
                }
                else if(length(temp.rgb - FOG_END) < 0.005) {
                    outColor = vec4(vec3(float(DIM_END) / 255.0), 1.0);
                }
                else {
                    outColor = vec4(0.0, 0.0, 0.0, 1.0);
                }
            }
        }
        else if (index == 30) {
            int currflags = 0;
            vec4 dimtmp = texture(PrevDataSampler, startData + 28.0 * incData);
            float dim = DIM_UNKNOWN;
            if (dimtmp.a == 1.0) {
                dim = int(dimtmp.r * 255.0);
            }
            if (((dim == DIM_UNKNOWN || dim == DIM_END) && temp.b > 0.2) || (dim == DIM_NETHER && temp.b > temp.g * 9.0)) {
                currflags |= FLAG_UNDERWATER;
                outColor = vec4(float(currflags) / 255.0, 0.0, 0.0, 1.0);
            }
            else if (dim == DIM_OVER) {
                outColor = texture(PrevDataSampler, startData + 30.0 * incData);
            }
        }
        // base case zero
        else {
            outColor = vec4(0.0);
        }
    }
    else {
        if (index == 25) {
            int fstart = decodeInt(texture(DiffuseSampler, start + 26.0 * inc).rgb);
            if (fstart == -8) {
                outColor = vec4(FOG_WATER, 1.0);
            }             
            else {
                outColor = vec4(mix(temp.rgb, FOG_CAVE, decodeFloat(texture(PrevDataSampler, startData + 48.0 * incData).rgb)), 1.0);
            }
        }
        else if (index == 26) {
            outColor = vec4(encodeInt(0), 1.0);
        }
        else if (index == 27) {
            int fstart = decodeInt(texture(DiffuseSampler, start + 26.0 * inc).rgb);
            float rain = texture(DiffuseSampler, start + 29.0 * inc).r;
            int fend = int(FOG_WATER_FAR);
            if (fstart != -8) {
                fend = int(float(decodeInt(texture(DiffuseSampler, start + 27.0 * inc).rgb)) * (FOG_DIST_MULT - FOG_DIST_OVERCAST_REDUCE * rain));
            }
            outColor = vec4(encodeFloat(log(FOG_TARGET) / float(-fend)), 1.0);
        }
        else if (index == 28) {
            outColor = texture(PrevDataSampler, startData + 28.0 * incData);
            if (outColor.a != 1.0 || int(outColor.r * 255.0) > DIM_MAX || outColor.r == 0.0) {
                outColor = texture(DiffuseSampler, start + 28.0 * inc);
            }
        }
        else if (index == 30) {
            int currflags = int(texture(DiffuseSampler, start + 30.0 * inc).r * 255.0);
            int fstart = decodeInt(texture(DiffuseSampler, start + 26.0 * inc).rgb);
            if (fstart == -8) {
                currflags |= FLAG_UNDERWATER;
            }
            outColor = vec4(float(currflags) / 255.0, 0.0, 0.0, 1.0);
        }
        // base case passthrough
        else {
            outColor = texture(DiffuseSampler, start + float(index) * inc);
        }
    }
    
    fragColor = outColor;
}

#version 330

in vec4 Position;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform vec2 AuxSize0;
uniform sampler2D DataSampler;

out vec2 texCoord;
out vec3 sunDir;
out vec3 moonDir;
out mat4 Proj;
out mat4 ProjInv;
out float near;
out float far;
out float dim;
out float rain;
out float underWater;
out float sdu;
out float mdu;
out vec3 direct;
out vec3 ambient;
out vec3 backside;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define PROJNEAR 0.05

#define FLAG_UNDERWATER 1<<0

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

// tweak lighting color here
#define NOON_CLEAR vec3(1.2, 1.1, 0.95) * 4.0
#define NOONA_CLEAR vec3(0.55, 0.57, 0.7) * 2.5
#define NOONM_CLEAR vec3(0.45, 0.47, 0.6) * 2.5
#define EVENING_CLEAR vec3(1.3, 0.9, 0.5) * 2.5
#define EVENINGA_CLEAR vec3(0.55, 0.57, 0.65) * 1.5
#define EVENINGM_CLEAR vec3(0.4, 0.45, 0.6) * 1.5
#define NIGHT_CLEAR vec3(0.65, 0.65, 0.7) * 0.6
#define NIGHTA_CLEAR vec3(0.75, 0.75, 0.8) * 0.6
#define NIGHTM_CLEAR vec3(1.2, 1.3, 1.4) * 0.7

#define NOON_OVERCAST vec3(1.0, 1.05, 1.1) * 2.2
#define NOONA_OVERCAST vec3(0.65, 0.67, 0.7) * 2.2
#define NOONM_OVERCAST vec3(0.6, 0.6, 0.6) * 2.2
#define EVENING_OVERCAST vec3(1.0, 0.9, 0.85) * 1.0
#define EVENINGA_OVERCAST vec3(0.65, 0.67, 0.7) * 1.0
#define EVENINGM_OVERCAST vec3(0.55, 0.55, 0.55) * 1.0
#define NIGHT_OVERCAST vec3(0.65, 0.65, 0.65) * 0.6
#define NIGHTA_OVERCAST vec3(0.75, 0.75, 0.75) * 0.6
#define NIGHTM_OVERCAST vec3(1.0, 1.0, 1.0) * 0.6

#define END_CLEAR vec3(0.8, 0.85, 0.85)
#define ENDA_CLEAR vec3(0.9, 0.9, 0.95)
#define ENDM_CLEAR vec3(1.0, 0.9, 1.0)

#define NETHER_CLEAR vec3(1.15, 1.1, 1.0)
#define NETHERA_CLEAR vec3(1.1, 1.0, 1.0)
#define NETHERM_CLEAR vec3(1.0, 1.0, 1.0)

#define UNKNOWN_CLEAR vec3(0.95)
#define UNKNOWNA_CLEAR vec3(1.0)
#define UNKNOWNM_CLEAR vec3(1.05)

vec2 getControl(int index, vec2 screenSize) {
    return vec2(float(index) + 0.5, 0.5) / screenSize;
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

// Control Map:
#define CTL_SUNDIRX         0
#define CTL_SUNDIRY         1
#define CTL_SUNDIRZ         2
#define CTL_ATAN_PMAT00     3
#define CTL_ATAN_PMAT11     4
#define CTL_PMAT10          5
#define CTL_PMAT01          6
#define CTL_PMAT12          7
#define CTL_PMAT13          8
#define CTL_PMAT20          9
#define CTL_PMAT21          10
#define CTL_PMAT22          11
#define CTL_PMAT23          12
#define CTL_PMAT30          13
#define CTL_PMAT31          14
#define CTL_PMAT32          15
#define CTL_MVMAT00         16
#define CTL_MVMAT01         17
#define CTL_MVMAT02         18
#define CTL_MVMAT10         19
#define CTL_MVMAT11         20
#define CTL_MVMAT12         21
#define CTL_MVMAT20         22
#define CTL_MVMAT21         23
#define CTL_MVMAT22         24
#define CTL_FOGCOLOR        25
#define CTL_FOGSTART        26
#define CTL_FOGEND          27 // also FogLambda
#define CTL_DIM             28
#define CTL_RAINSTRENGTH    29
#define CTL_MISCFLAGS       30 // bit0:underwater
#define CTL_FARCLIP         31

// Additional Post Map:
#define CTL_EXP0            47
#define CTL_EXP1            48
#define CTL_EXP2            49
#define CTL_EXP3            50
#define CTL_EXP4            51
#define CTL_EXP5            52
#define CTL_EXP6            53
#define CTL_EXP7            54
#define CTL_EXP8            55
#define CTL_EXPAVG          56
#define CTL_APPLYLIGHT0     57
#define CTL_APPLYLIGHT1     58
#define CTL_APPLYLIGHT2     59
#define CTL_APPLYLIGHT3     60
#define CTL_APPLYLIGHT4     61
#define CTL_APPLYLIGHTAVG   62
#define CTL_CAVE            63

void main() {
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = Position.xy / OutSize;

    //simply decoding all the control data and constructing the sunDir, ProjMat, ModelViewMat

    vec2 start = getControl(0, AuxSize0);
    vec2 inc = vec2(1.0 / AuxSize0.x, 0.0);

    // RealProjMat constructed fully
    mat4 RealProjMat = mat4(tan(decodeFloat(texture(DataSampler, start + CTL_ATAN_PMAT00 * inc).xyz)), decodeFloat(texture(DataSampler, start + CTL_PMAT01 * inc).xyz), 0.0, 0.0,
                        decodeFloat(texture(DataSampler, start + CTL_PMAT10 * inc).xyz), tan(decodeFloat(texture(DataSampler, start + CTL_ATAN_PMAT11 * inc).xyz)), decodeFloat(texture(DataSampler, start + CTL_PMAT12 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_PMAT13 * inc).xyz),
                        decodeFloat(texture(DataSampler, start + CTL_PMAT20 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_PMAT21 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_PMAT22 * inc).xyz),  decodeFloat(texture(DataSampler, start + CTL_PMAT23 * inc).xyz),
                        decodeFloat(texture(DataSampler, start + CTL_PMAT30 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_PMAT31 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_PMAT32 * inc).xyz), 0.0);

    mat4 ModelViewMat = mat4(decodeFloat(texture(DataSampler, start + CTL_MVMAT00 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT01 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT02 * inc).xyz), 0.0,
                        decodeFloat(texture(DataSampler, start + CTL_MVMAT10 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT11 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT12 * inc).xyz), 0.0,
                        decodeFloat(texture(DataSampler, start + CTL_MVMAT20 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT21 * inc).xyz), decodeFloat(texture(DataSampler, start + CTL_MVMAT22 * inc).xyz), 0.0,
                        0.0, 0.0, 0.0, 1.0);

    sunDir = vec3(decodeFloat(texture(DataSampler, start + CTL_SUNDIRX * inc).xyz), 
                  decodeFloat(texture(DataSampler, start + CTL_SUNDIRY * inc).xyz), 
                  decodeFloat(texture(DataSampler, start + CTL_SUNDIRZ * inc).xyz));
    sunDir = normalize(sunDir);

    near = PROJNEAR;
    far = float(decodeInt(texture(DataSampler, start + CTL_FARCLIP * inc).xyz));

    Proj = RealProjMat * ModelViewMat;
    ProjInv = inverse(Proj);

    dim = texture(DataSampler, start + CTL_DIM * inc).r * 255.0;

    rain = texture(DataSampler, start + CTL_RAINSTRENGTH * inc).r;

    int flags = int(texture(DataSampler, start + CTL_MISCFLAGS * inc).r * 255.0);
    underWater = float((flags & FLAG_UNDERWATER) > 0);

    // get lighting color
    moonDir = normalize(vec3(-sunDir.xy, 0.0));
    sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
    mdu = dot(vec3(0.0, 1.0, 0.0), moonDir);

    if (abs(dim - DIM_OVER) < 0.01) {
        vec3 evening = mix(EVENING_CLEAR, EVENING_OVERCAST, rain);
        vec3 evening_a = mix(EVENINGA_CLEAR, EVENINGA_OVERCAST, rain);
        vec3 evening_m = mix(EVENINGM_CLEAR, EVENINGM_OVERCAST, rain);
        if (sdu > 0.0) {
            vec3 noon = mix(NOON_CLEAR, NOON_OVERCAST, rain);
            vec3 noon_a = mix(NOONA_CLEAR, NOONA_OVERCAST, rain);
            vec3 noon_m = mix(NOONM_CLEAR, NOONM_OVERCAST, rain);
            direct = mix(evening, noon, sdu);
            ambient = mix(evening_a, noon_a, sdu);
            backside = mix(evening_m, noon_m, sdu);
        } else {
            vec3 night = mix(NIGHT_CLEAR, NIGHT_OVERCAST, rain);
            vec3 night_a = mix(NIGHTA_CLEAR, NIGHTA_OVERCAST, rain);
            vec3 night_m = mix(NIGHTM_CLEAR, NIGHTM_OVERCAST, rain);
            direct = mix(evening, night, clamp(pow(-sdu * 3.0, 0.5), 0.0, 1.0));
            ambient = mix(evening_a, night_a, pow(-sdu, 0.5));
            backside = mix(evening_m, night_m, pow(-sdu, 0.5));
        }
    }
    else if (abs(dim - DIM_END) < 0.01) {
        direct = END_CLEAR;
        ambient = ENDA_CLEAR;
        backside = ENDM_CLEAR;
    }
    else if (abs(dim - DIM_NETHER) < 0.01) {
        direct = NETHER_CLEAR;
        ambient = NETHERA_CLEAR;
        backside = NETHERM_CLEAR;
    }
    else {
        direct = UNKNOWN_CLEAR;
        ambient = UNKNOWNA_CLEAR;
        backside = UNKNOWNM_CLEAR;
    }
}

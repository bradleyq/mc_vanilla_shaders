#version 330

in vec4 Position;

uniform sampler2D DataSampler;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform vec2 AuxSize0;

out vec2 texCoord;
out vec2 oneTexel;
out float exposureNorm;
out float exposureClamp;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define PROJFAR 1024.0
#define PI 3.14159265358979

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

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = outPos.xy * 0.5 + 0.5;
    oneTexel = 1.0 / OutSize;

    vec2 start = getControl(0, AuxSize0);
    vec2 inc = vec2(1.0 / AuxSize0.x, 0.0);

    float rain = texture(DataSampler, start + CTL_RAINSTRENGTH * inc).r;
    float cave = decodeFloat(texture(DataSampler, start + CTL_CAVE * inc).rgb);
    
    float exposure = decodeFloat(texture(DataSampler, start + CTL_EXPAVG * inc).rgb) + 2.0;
    exposureNorm = (clamp(exposure, 0.5, 1.6) - 0.5) / 1.1;
    exposureClamp = clamp(exposure, 0.5, 1.6);
}

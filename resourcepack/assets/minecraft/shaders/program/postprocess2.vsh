#version 330

in vec4 Position;

uniform sampler2D DataSampler;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform vec2 AuxSize0;

out vec2 texCoord;
out vec2 oneTexel;
out float exposure;

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
    return vec4(color.r + float((alpha >> 4) % 4), color.g + float((alpha >> 2) % 4), color.b + float(alpha % 4), 1.0);
}

vec4 encodeHDR_0(vec4 color) {
    int alpha = 3;
    color = clamp(color, 0.0, 4.0);
    vec3 colorFloor = clamp(floor(color.rgb), 0.0, 3.0);

    alpha = alpha << 2;
    alpha += int(colorFloor.r);
    alpha = alpha << 2;
    alpha += int(colorFloor.g);
    alpha = alpha << 2;
    alpha += int(colorFloor.b);

    return vec4(color.rgb - colorFloor, alpha / 255.0);
}

vec4 decodeHDR_1(vec4 color) {
    return vec4(color.rgb * (color.a + 1.0), 1.0);
}

vec4 encodeHDR_1(vec4 color) {
    float maxval = max(color.r, max(color.g, color.b));
    float mult = (maxval - 1.0) * 255.0 / 3.0;
    mult = clamp(ceil(mult), 0.0, 255.0);
    color.rgb = color.rgb * 255 / (mult / 255 * 3 + 1);
    color.rgb = round(color.rgb);
    return vec4(color.rgb, mult) / 255.0;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = outPos.xy * 0.5 + 0.5;
    oneTexel = 1.0 / OutSize;

    vec2 start = getControl(0, AuxSize0);
    vec2 inc = vec2(1.0 / AuxSize0.x, 0.0);

    exposure = decodeFloat(texture(DataSampler, start + 41.0 * inc).rgb) + 2.0;
    float rain = texture(DataSampler, start + 29.0 * inc).r;
    float cave = decodeFloat(texture(DataSampler, start + 48.0 * inc).rgb);
    exposure *= 1.0 + 0.4 * rain * (1.0 - cave);
}

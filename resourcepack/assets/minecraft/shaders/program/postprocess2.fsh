#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D BloomSampler;

in vec2 texCoord;
in vec2 oneTexel;
in float exposureNorm;
in float exposureClampAdjusted;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define PROJFAR 1024.0
#define PI 3.14159265358979

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

#define CLAMP_EDGE oneTexel * 0.55
vec2 clampInBound(vec2 coords, float bound) {
    return clamp(coords, vec2(bound, 0.0) + CLAMP_EDGE, vec2(2.0 * bound, bound) - CLAMP_EDGE);
}

vec3 acesTonemap(vec3 x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.1;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float customRolloff9(float x) {
    return x > 0.5555 ? 0.9 * (x - 0.5555) / (x - 0.5555 + 1.0) + 0.5 : 0.9 * x;
}

float customRolloff10(float x) {
    return x > 0.5 ? (x - 0.5) / (x - 0.5 + 1.0) + 0.5 : x;
}

vec3 jodieReinhardTonemap(vec3 c, float upper) {
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (upper * c + 1.0);

    return mix(c / (upper * l + 1.0), tc, tc);
}

void main() {
    vec4 outColor = decodeHDR_0(texture(DiffuseSampler, texCoord));

    float bound = 0.5;
    vec2 scaledCoord = (texCoord + vec2(1.0, 0.0)) * bound;

    vec4 bloomCol = 4.0 * decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord, bound)))
                  + 2.0 * decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, 0.0), bound)))
                  + 2.0 * decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, 0.0), bound)))
                  + 2.0 * decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord + 0.99 * vec2(0.0, oneTexel.y), bound)))
                  + 2.0 * decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord - 0.99 * vec2(0.0, oneTexel.y), bound)))
                  + decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, oneTexel.y), bound)))
                  + decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, oneTexel.y), bound)))
                  + decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, -oneTexel.y), bound)))
                  + decodeHDR_0(texture(BloomSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, -oneTexel.y), bound)));  
    bloomCol /= 16.0; 

    float startB = 1.0 + 5.0 * exposureNorm;
    float endB = 2.0 + 4.8 * exposureNorm;

    bloomCol -= outColor;
    bloomCol = max(bloomCol, vec4(0.0));

    // apply bloom
    outColor += bloomCol * 0.5 * (pow(1.0 - exposureNorm, 2.0) * 0.5 + 0.5);
    // outColor = bloomCol;

    // apply crosstalk
    outColor.rgb += vec3(0.05) * (outColor.r + outColor.g + outColor.b);

    // apply exposure
    outColor.rgb /= exposureClampAdjusted * 2.0;

    // apply tonemap
    outColor.rgb = vec3(customRolloff9(outColor.r), customRolloff9(outColor.g), customRolloff9(outColor.b));

    fragColor = outColor;
}
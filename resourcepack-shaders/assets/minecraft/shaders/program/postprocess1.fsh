#version 330

uniform sampler2D DiffuseSampler;
uniform float Level;

in vec2 texCoord;
in vec2 oneTexel;

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

void main() {
    vec4 outColor;
    float bound = pow(0.5, Level);
    if (texCoord.x > bound && texCoord.x < 2.0 * bound && texCoord.y > 0.0 && texCoord.y < bound) {
        vec2 scaledCoord = 0.5 * texCoord;

        outColor = 4.0 * decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord, 0.5 * bound)))
                 + 2.0 * decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, 0.0), 0.5 * bound)))
                 + 2.0 * decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, 0.0), 0.5 * bound)))
                 + 2.0 * decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord + 0.99 * vec2(0.0, oneTexel.y), 0.5 * bound)))
                 + 2.0 * decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord - 0.99 * vec2(0.0, oneTexel.y), 0.5 * bound)))
                 + decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, oneTexel.y), 0.5 * bound)))
                 + decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, oneTexel.y), 0.5 * bound)))
                 + decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord + 0.99 * vec2(oneTexel.x, -oneTexel.y), 0.5 * bound)))
                 + decodeHDR_0(texture(DiffuseSampler, clampInBound(scaledCoord - 0.99 * vec2(oneTexel.x, -oneTexel.y), 0.5 * bound)));   

        outColor /= 16.0;
        outColor = encodeHDR_0(outColor);
    }
    else {
        outColor = texture(DiffuseSampler, texCoord);
    }

    fragColor = outColor;
}
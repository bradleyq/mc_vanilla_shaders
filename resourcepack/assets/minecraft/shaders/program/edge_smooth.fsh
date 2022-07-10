#version 330

uniform sampler2D DiffuseSampler;
uniform vec2 OutSize;

in vec2 texCoord;
flat in vec2 oneTexel;

out vec4 fragColor;

#define FPRECISION 4000000.0
#define KERNEL mat3(1.0/16.0, 1.0/8.0, 1.0/16.0, 1.0/8.0, 1.0/4.0, 1.0/8.0, 1.0/16.0, 1.0/8.0, 1.0/16.0)

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

void main() {
    float result = 0.0;
    for (int i = 0; i < 9; i += 1) {
        int x = i % 3;
        int y = i / 3;
        result += KERNEL[x][y] * decodeFloat(texture(DiffuseSampler, texCoord - oneTexel + vec2(oneTexel.x * x, oneTexel * y)).xyz);
    }
    fragColor = vec4(encodeFloat(clamp(result, 0.0, 2.0)), 1.0);
}

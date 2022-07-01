#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform vec2 OutSize;

in vec2 texCoord;
flat in vec2 oneTexel;
flat in mat4 ProjInv;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define NUMCONTROLS 28
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

int inControl(vec2 screenCoord, float screenWidth) {
    float start = floor(screenWidth / 4.0) * 2.0;
    int index = int(screenCoord.x - start) / 2;
    if (screenCoord.y < 1.0 && screenCoord.x > start && int(screenCoord.x) % 2 == 0 && index < NUMCONTROLS) {
        return index;
    }
    return -1;
}

vec4 getNotControl(sampler2D inSampler, vec2 coords, bool inctrl) {
    if (inctrl) {
        return (texture(inSampler, coords - vec2(oneTexel.x, 0.0)) + texture(inSampler, coords + vec2(oneTexel.x, 0.0)) + texture(inSampler, coords + vec2(0.0, oneTexel.y))) / 3.0;
    } else {
        return texture(inSampler, coords);
    }
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

// vec3 encodeFloat(float val) {
//     uint sign = val > 0.0 ? 0u : 1u;
//     uint exponent = uint(clamp(ceil(log2(abs(val))) + 31, 0.0, 63.0));
//     uint mantissa = uint((abs(val) * pow(2.0, -float(exponent) + 31.0 + 17.0)));
//     return vec3(
//         ((sign & 1u) << 7u) | ((exponent & 63u) << 1u) | (mantissa >> 16u) & 1u,
//         (mantissa >> 8u) & 255u,
//         mantissa & 255u
//     ) / 255.0;
// }

// float decodeFloat(vec3 raw) {
//     uvec3 scaled = uvec3(raw * 255.0);
//     uint sign = scaled.r >> 7;
//     uint exponent = ((scaled.r >> 1u) & 63u);
//     uint mantissa = ((scaled.r & 1u) << 16u) | (scaled.g << 8u) | scaled.b;
//     return (-float(sign) * 2.0 + 1.0) * float(mantissa)  * pow(2.0, float(exponent) - 31.0 - 17.0);
// }

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

vec2 ndcScale(vec2 rawCoord) {
    return 2.0 * (rawCoord - vec2(0.5));
}

void main() {
    fragColor = texture(DiffuseSampler, texCoord);
    if (fragColor.r > -1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }

    vec2 coord0 = texCoord - vec2(0.0, oneTexel.y);
    vec2 coord1 = texCoord - vec2(oneTexel.x, 0.0); 
    vec2 coord2 = texCoord;
    vec2 coord3 = texCoord + vec2(oneTexel.x, 0.0);
    vec2 coord4 = texCoord + vec2(0.0, oneTexel.y);
    vec2 coord5 = texCoord + vec2(-oneTexel.x, -oneTexel.y);
    vec2 coord6 = texCoord + vec2(-oneTexel.x, oneTexel.y); 
    vec2 coord7 = texCoord + vec2(oneTexel.x, -oneTexel.y);
    vec2 coord8 = texCoord + vec2(oneTexel.x, oneTexel.y);

    vec3 p0 = backProject(vec4(ndcScale(coord0), 2.0 * (getNotControl(DiffuseDepthSampler, coord0, inControl(coord0 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p1 = backProject(vec4(ndcScale(coord1), 2.0 * (getNotControl(DiffuseDepthSampler, coord1, inControl(coord1 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p2 = backProject(vec4(ndcScale(coord2), 2.0 * (getNotControl(DiffuseDepthSampler, coord2, inControl(coord2 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p3 = backProject(vec4(ndcScale(coord3), 2.0 * (getNotControl(DiffuseDepthSampler, coord3, inControl(coord3 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p4 = backProject(vec4(ndcScale(coord4), 2.0 * (getNotControl(DiffuseDepthSampler, coord4, inControl(coord4 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p5 = backProject(vec4(ndcScale(coord5), 2.0 * (getNotControl(DiffuseDepthSampler, coord5, inControl(coord5 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p6 = backProject(vec4(ndcScale(coord6), 2.0 * (getNotControl(DiffuseDepthSampler, coord6, inControl(coord6 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p7 = backProject(vec4(ndcScale(coord7), 2.0 * (getNotControl(DiffuseDepthSampler, coord7, inControl(coord7 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;
    vec3 p8 = backProject(vec4(ndcScale(coord8), 2.0 * (getNotControl(DiffuseDepthSampler, coord8, inControl(coord8 * OutSize, OutSize.x) > -1).r - 0.5), 1.0)).xyz;

    float vcomp = 0.0; 
    float hcomp = 0.0;
    float vcompd = 0.0;
    float hcompd = 0.0;

    vcomp = pow(0.5 * (dot(normalize(p2 - p0), normalize(p2 - p4)) + 1.0), 2.0);
    hcomp = pow(0.5 * (dot(normalize(p2 - p1), normalize(p2 - p3)) + 1.0), 2.0);
    vcompd = pow(0.5 * (dot(normalize(p2 - p5), normalize(p2 - p8)) + 1.0), 2.0);
    hcompd = pow(0.5 * (dot(normalize(p2 - p6), normalize(p2 - p7)) + 1.0), 2.0);

    fragColor.rgb = encodeFloat(sqrt((vcomp * vcomp + hcomp * hcomp) * 2.0));
}

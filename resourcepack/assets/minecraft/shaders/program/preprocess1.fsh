#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;

uniform vec2 InSize;
uniform vec2 OutSize;

in vec2 texCoord;
in vec2 oneTexel;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define NUMCONTROLS 30
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define PROJFAR 1024.0
#define FUDGE 32.0
#define PI 3.14159265358979

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define FACETYPE_Y 0
#define FACETYPE_X 1
#define FACETYPE_Z 2
#define FACETYPE_S 3

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

float luminance(vec3 rgb) {
    return max(max(rgb.r, rgb.g), rgb.b);
}

int inControl(vec2 screenCoord, float screenWidth) {
    float start = floor(screenWidth / 4.0) * 2.0;
    int index = int(screenCoord.x - start) / 2;
    if (screenCoord.y < 1.0 && screenCoord.x > start && int(screenCoord.x) % 2 == 0 && index < NUMCONTROLS) {
        return index;
    }
    return -1;
}

vec4 encodeUInt(uint i) {
    uint r = (i) % 256u;
    uint g = (i >> 8u) % 256u;
    uint b = (i >> 16u) % 256u;
    uint a = (i >> 24u) % 256u;
    return vec4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0 , float(a) / 255.0);
}

uint decodeUInt(vec4 ivec) {
    ivec *= 255.0;
    return uint(ivec.r) + (uint(ivec.g) << 8u) + (uint(ivec.b) << 16u) + (uint(ivec.a) << 24u);
}

vec4 encodeDepth(float depth) {
    return encodeUInt(floatBitsToUint(depth)); 
}

float decodeDepth(vec4 depth) {
    return uintBitsToFloat(decodeUInt(depth)); 
}


void main() {
    vec4 outColor = vec4(0.0);
    float outDepth = texture(DiffuseDepthSampler, texCoord).r;
    bool inctrl = inControl(texCoord * OutSize, OutSize.x) > -1;

    // remove control pixel
    if (inctrl) {
        // average left and right depths
        outDepth = (texture(DiffuseDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r + texture(DiffuseDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r) / 2.0;
    }
    else {
        outColor = texture(DiffuseSampler, texCoord);
        outDepth = texture(DiffuseDepthSampler, texCoord).r;

        // remove translucent checker pixels pixels
        if ((int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 0 
          && linearizeDepth(outDepth) < PROJFAR - FUDGE 
          && int(outColor.a * 255.0) % 4 == FACETYPE_S 
          && int(outColor.b * 255.0) % 8 >= PBRTYPE_TRANSLUCENT) {
            vec4 p0 = texture(DiffuseSampler, texCoord - vec2(oneTexel.x, 0.0));
            vec4 p1 = texture(DiffuseSampler, texCoord + vec2(oneTexel.x, 0.0));
            vec4 p2 = texture(DiffuseSampler, texCoord - vec2(0.0, oneTexel.y));
            vec4 p3 = texture(DiffuseSampler, texCoord + vec2(0.0, oneTexel.y));

            // average left and right depth if they are within 0.25
            outDepth = texture(DiffuseDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r;
            float dtmp = texture(DiffuseDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r;
            if (abs(linearizeDepth(outDepth) - linearizeDepth(dtmp)) < 0.25) {
                outDepth = (outDepth + dtmp) / 2.0;
            }
        }
    }

    outColor = encodeDepth(outDepth);
    fragColor = outColor;
}

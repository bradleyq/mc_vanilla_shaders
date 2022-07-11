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


void main() {
    vec4 outColor = vec4(0.0);
    bool inctrl = inControl(texCoord * OutSize, OutSize.x) > -1;

    // remove control pixel
    if (inctrl) {
        vec4 p0 = texture(DiffuseSampler, texCoord - vec2(oneTexel.x, 0.0));
        vec4 p1 = texture(DiffuseSampler, texCoord + vec2(oneTexel.x, 0.0));
        vec4 p2 = texture(DiffuseSampler, texCoord + vec2(0.0, oneTexel.y));

        // average luma of left right up, take chroma of above, take material of left
        outColor = vec4((p0.r + p1.r + p2.r) / 3.0, p2.g, p0.b, p0.a);
    }
    else {
        outColor = texture(DiffuseSampler, texCoord);
        float depth = texture(DiffuseDepthSampler, texCoord).r;
        int pbrtype = int(outColor.b * 255.0) % 8;

        // remove translucent checker pixels pixels
        if ((int(gl_FragCoord.x) + int(gl_FragCoord.y)) % 2 == 0 
          && linearizeDepth(depth) < PROJFAR - FUDGE 
          && int(outColor.a * 255.0) % 4 == FACETYPE_S 
          && pbrtype >= PBRTYPE_TRANSLUCENT) {
            vec4 p0 = texture(DiffuseSampler, texCoord - vec2(oneTexel.x, 0.0));
            vec4 p1 = texture(DiffuseSampler, texCoord + vec2(oneTexel.x, 0.0));
            vec4 p2 = texture(DiffuseSampler, texCoord - vec2(0.0, oneTexel.y));
            vec4 p3 = texture(DiffuseSampler, texCoord + vec2(0.0, oneTexel.y));

            // average luma left right up down, average chroma up down, take material of left
            vec2 yuv = vec2((p0.r + p1.r + p2.r + p3.r) / 4.0, (p2.g + p3.g) / 2.0 - 0.5);

            float strength = clamp(float(int(outColor.b * 255.0) / 16) / 15.0, 0.0, 1.0);
            vec2 specialComp = vec2(outColor.r, outColor.g - 0.5);
            if (pbrtype == PBRTYPE_TEMISSIVE) {
                yuv += specialComp * strength;
            }
            else if (pbrtype == PBRTYPE_TRANSLUCENT) {
                yuv = mix(yuv, specialComp, strength);
            }
            yuv.g += 0.5;

            outColor = vec4(yuv, p0.b, p0.a);
        }
    }

    fragColor = outColor;
}

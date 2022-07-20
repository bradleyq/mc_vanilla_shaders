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

vec3 YUV2RGB(vec3 yuv) {
    vec3 outColor = vec3(0.0);
    yuv.yz -= 0.5;
    outColor.r = yuv.x * 1.0 + yuv.y * 0.0 + yuv.z * 1.4;
    outColor.g = yuv.x * 1.0 + yuv.y * -0.343 + yuv.z * -0.711;
    outColor.b = yuv.x * 1.0 + yuv.y * 1.765 + yuv.z * 0.0;
    return outColor;
}

void main() {
    vec4 outColor = vec4(0.0);
    vec2 adjustedCoord = texCoord;
    if (gl_FragCoord.y < 0.75) { // avoid control pixel row
        adjustedCoord.y += oneTexel.y;
    }

    // float strength = clamp(float(int(outColor.b * 255.0) / 16) / 15.0, 0.0, 1.0);
    // int(outColor.a * 255.0) % 4 == FACETYPE_S 
    // int pbrtype = int(outColor.b * 255.0) % 8;
    //     if (int(pixCoord.x) % 2 == 0) {
    //     yuv = vec3(inCol.xy, sec);
    // }
    // else {
    //     yuv = vec3(inCol.x, sec, inCol.y);
    // }

    vec3 yuv = vec3(0.0);
    float strength = 0.0;
    bool valid = false;
    float bval = 0.0;
    float bvalcount = 0.0;
    int pbrtype = PBRTYPE_STANDARD;

    if ((int(adjustedCoord.x * OutSize.x) + int(adjustedCoord.y * OutSize.y)) % 2 == 0) {
        vec4 p0 = texture(DiffuseSampler, adjustedCoord);
        pbrtype = int(p0.b * 255.0) % 8;

        if (p0.a == 1.0 && pbrtype == PBRTYPE_TRANSLUCENT || pbrtype == PBRTYPE_TEMISSIVE) {
            valid = true;
            strength = clamp(float(int(p0.b * 255.0) / 16) / 15.0, 0.0, 1.0);
            yuv.rg = p0.rg;

            vec4 ptmp = texture(DiffuseSampler, adjustedCoord + vec2(-oneTexel.x, oneTexel.y));
            if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                bvalcount += 1.0;
                bval += ptmp.g;
            }

            ptmp = texture(DiffuseSampler, adjustedCoord + vec2(oneTexel.x, oneTexel.y));
            if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                bvalcount += 1.0;
                bval += ptmp.g;
            }

            if (gl_FragCoord.y > 1.75) { // avoid control pixel row
                ptmp = texture(DiffuseSampler, adjustedCoord + vec2(-oneTexel.x, -oneTexel.y));
                if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                    bvalcount += 1.0;
                    bval += ptmp.g;
                }

                ptmp = texture(DiffuseSampler, adjustedCoord + vec2(oneTexel.x, -oneTexel.y));
                if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                    bvalcount += 1.0;
                    bval += ptmp.g;
                }
            }

            if (bvalcount == 0.0) { // no valid supplementary pixels, default to 0.5
                bval += 0.5;
                bvalcount += 1.0;
            }
        }
    }
    else {
        vec4 p0 = texture(DiffuseSampler, adjustedCoord + vec2(0.0, oneTexel.y));
        pbrtype = int(p0.b * 255.0) % 8;

        // avoid control pixel row
        vec4 p1 = gl_FragCoord.y > 1.75 ? texture(DiffuseSampler, adjustedCoord + vec2(0.0, -oneTexel.y)) : vec4(0.0);
        int pbrtypetmp = int(p1.b * 255.0) % 8;

        vec2 rgval = vec2(0.0);
        float rgvalcount = 0.0;

        if (p0.a == 1.0 && pbrtype == PBRTYPE_TRANSLUCENT || pbrtype == PBRTYPE_TEMISSIVE) {
            rgval += p0.rg;
            rgvalcount += 1.0;
        }

        if (p1.a == 1.0 && pbrtypetmp == PBRTYPE_TRANSLUCENT || pbrtype == PBRTYPE_TEMISSIVE) {
            rgval += p1.rg;
            rgvalcount += 1.0;
            pbrtype = pbrtypetmp;
            p0 = p1;
        }

        if (rgvalcount > 0.0) {
            vec4 ptmp = texture(DiffuseSampler, adjustedCoord + vec2(-oneTexel.x, 0));
            if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                bvalcount += 1.0;
                bval += ptmp.g;
            }

            ptmp = texture(DiffuseSampler, adjustedCoord + vec2(oneTexel.x, 0));
            if (ptmp.a == 1.0 && pbrtype == int(ptmp.b * 255.0) % 8) {
                bvalcount += 1.0;
                bval += ptmp.g;
            }

            if (bvalcount > 0.0) { // only a valid pixel if at least one left right and one up down
                valid = true;
                strength = clamp(float(int(p0.b * 255.0) / 16) / 15.0, 0.0, 1.0);
                yuv.rg = rgval / rgvalcount;
            }
        }
    }

    if (valid) {
        yuv.b = bval / bvalcount;

        if (int(gl_FragCoord.x) % 2 == 1) {
            yuv = yuv.rbg;
        }

        outColor.rgb = YUV2RGB(yuv);
        outColor.a = float(int(strength * 255.0) / 2 * 2 + int(pbrtype == PBRTYPE_TEMISSIVE)) / 255.0;
    }

    fragColor = outColor;
}

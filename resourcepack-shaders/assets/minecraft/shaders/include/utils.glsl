#version 330

#define NUMCONTROLS 32
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define TINY 8e-8
#define PI 3.14159265359
#define LIGHT0_DIRECTION vec3(0.2, 1.0, -0.7) // Default light 0 direction everywhere except in inventory
#define LIGHT1_DIRECTION vec3(-0.2, 1.0, 0.7) // Default light 1 direction everywhere except in nether and inventory

#define ALPHACUTOFF 21.5 / 255.0
#define WAVINGT 21
#define WAVINGS 22
#define SUBSSMIN 21
#define SUBSSMAX 47
#define EMISSMIN 48
#define EMISSMAX 72
#define ROUGHMIN 73
#define ROUGHMAX 157
#define METALMIN 158
#define METALMAX 251

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define FACETYPE_Y 0
#define FACETYPE_X 1
#define FACETYPE_Z 2
#define FACETYPE_S 3

#define EMISSMULT 6.0
#define EMISSMULTP 1.0

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define FOG_WATER vec3(0.0 / 255.0, 37.0 / 255.0, 38.0 / 255.0)
#define FOG_END vec3(21.0 / 255.0, 17.0 / 255.0, 21.0 / 255.0)
#define FOG_LAVA vec3(153.0 / 255.0, 25.0 / 255.0, 0.0)
#define FOG_LAVA_END 2.0
#define FOG_LAVA_START 0.0
#define FOG_SNOW vec3(159.0 / 255.0, 187.0 / 255.0, 200.0 / 255.0)
#define FOG_SNOW_END 2.0
#define FOG_SNOW_START 0.0
#define FOG_BLIND vec3(0.0)
#define FOG_BLIND_START 1.25
#define FOG_BLIND_END 5.0
#define FOG_DARKNESS vec3(0.0)
#define FOG_DARKNESS_START 11.25
#define FOG_DARKNESS_END 15.0

#define FLAG_UNDERWATER 1<<0

/*
Control Map:

[0] sunDir.x
[1] sunDir.y
[2] sunDir.z
[3] arctan(ProjMat[0][0])
[4] arctan(ProjMat[1][1])
[5] ProjMat[1][0]
[6] ProjMat[0][1]
[7] ProjMat[1][2]
[8] ProjMat[1][3]
[9] ProjMat[2][0]
[10] ProjMat[2][1]
[11] ProjMat[2][2]
[12] ProjMat[2][3]
[13] ProjMat[3][0]
[14] ProjMat[3][1]
[15] ProjMat[3][2]
[16] ModelViewMat[0][0]
[17] ModelViewMat[0][1]
[18] ModelViewMat[0][2]
[19] ModelViewMat[1][0]
[20] ModelViewMat[1][1]
[21] ModelViewMat[1][2]
[22] ModelViewMat[2][0]
[23] ModelViewMat[2][1]
[24] ModelViewMat[2][2]
[25] FogColor
[26] FogStart
[27] FogEnd
[28] Dimension
[29] RainStrength
[30] MiscFlags bit0:underwater
[31] FarClip
*/

/*
BA Map:

B:[0-2] PBRType - 0:standard 1:emissive 2:subsurface 3:translucent 4:t-emissive 5:unused 6:unused 7:unused
B:[3] Unused
B:[4-7] Value - amount tied to "PBRType" 0-16

A:[0-1] FaceType - 0:x-axis 1:z-axis 2:y-axis 3:special
A:[2-7] ApplyLight - amount of shading to apply 0-63

B not used for standard type (FaceType != 0)
*/

// returns control pixel index or -1 if not control
int inControl(vec2 screenCoord, float screenWidth) {
    float start = floor(screenWidth / 4.0) * 2.0;
    int index = int(screenCoord.x - start) / 2;
    if (screenCoord.y < 1.0 && screenCoord.x > start && int(screenCoord.x) % 2 == 0 && index < NUMCONTROLS) {
        return index;
    }
    return -1;
}

#ifdef FSH
// discards the current pixel if it is control
void discardControl(vec2 screenCoord, float screenWidth) {
    if (inControl(screenCoord, screenWidth) >= 0) {
        discard;
    }
}

// discard but for when ScreenSize is not given
void discardControlGLPos(vec2 screenCoord, vec4 glpos) {
    float screenWidth = round(screenCoord.x * 2.0 / (glpos.x / glpos.w + 1.0));
    discardControl(screenCoord, screenWidth);
}
#endif

// get screen coordinates of a particular control index
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
    return encodeInt(int(round(f * FPRECISION)));
}

float decodeFloat(vec3 vec) {
    return decodeInt(vec) / FPRECISION;
}

// vec3 encodeFloat(float val) {
//     uint sign = val > 0.0 ? 0u : 1u;
//     uint exponent = uint(clamp(ceil(log2(abs(val) + TINY)) + 31, 0.0, 63.0));
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

// bool isGlowing(vec2 uv2) { // detect glowing signs / maps, but also catches maps and signs on glowstone in direct sky light. unfortunate....
//     if (uv2.x >= 209.999 && uv2.y >= 239.999) { 
//         return true;
//     }
//     return false;
// }

int getDirE(vec3 normal) {
    int dir = FACETYPE_Y;
    float dotx = abs(dot(normal, vec3(1.0, 0.0, 0.0)));
    float doty = abs(dot(normal, vec3(0.0, 1.0, 0.0)));
    float dotz = abs(dot(normal, vec3(0.0, 0.0, 1.0)));
    if (dotx > doty && dotx > dotz) {
        dir = FACETYPE_X;
    } else if (dotz > doty && dotz > dotx) {
        dir = FACETYPE_Z;
    }
    return dir;
}

int getDirB(vec3 normal) {
    int dir = FACETYPE_Y;
    if (abs(normal.x) > 0.999) {
        dir = FACETYPE_X;
    } else if (abs(normal.z) > 0.999) {
        dir = FACETYPE_Z;
    }
    return dir;
}

vec2 encodeYUV(vec2 coord, vec3 color) {
    vec2 outCol = vec2(0.0);
    outCol.x = color.r * 0.299 + color.g * 0.587 + color.b * 0.114;
    if (int(coord.x) % 2 == 0) {
        outCol.y = color.r * -0.169 + color.g * -0.331 + color.b * 0.5 + 0.5;
    }
    else {
        outCol.y = color.r * 0.5 + color.g * -0.419 + color.b * -0.081 + 0.5;
    }
    return outCol;
}

vec2 getBA(vec2 lightmask, int type, int facetype, float strength) {
    int b = 255;
    int a = 255;
    if (type != PBRTYPE_TRANSLUCENT && type != PBRTYPE_TEMISSIVE) {
        float af = 1.0 - smoothstep(5.0 / 15.0, 12.0 / 15.0, lightmask.y);

        if (type != PBRTYPE_EMISSIVE) {
            af = max(smoothstep(5.0 / 15.0, 1.0, lightmask.x), af);
        }

        a = int(round(af * 63.0)) * 4;
        if (type == PBRTYPE_STANDARD) {
            a += facetype;
        }
        else {
            a += FACETYPE_S;
        }
    }

    if (type != PBRTYPE_STANDARD) {
        b = int(round(strength * 15.0)) * 16 + type;
    }
    
    return vec2(float(b), float(a)) / 255.0;
}

vec4 getOutColorT(vec4 color, vec4 light, vec2 lightmask, vec2 fragcoord, int facetype, int type) {
    vec4 outCol = vec4(0.0);
    float strength = color.a;

    // get ambient, cave, and torch light
    if (type == PBRTYPE_EMISSIVE) { // emissive
        outCol.rgb = color.rgb * mix(light.rgb / (1.0 + strength * (EMISSMULT - 1.0)), vec3(1.0), strength);
    }
    else if (type == PBRTYPE_SUBSURFACE) { // subsurface
        outCol.rgb = color.rgb * light.rgb;
    }
    else if (type == PBRTYPE_TRANSLUCENT || type == PBRTYPE_TEMISSIVE) { // translucent
        outCol.rgb = color.rgb;
    }
    else { // all other materials
        outCol.rgb = color.rgb * light.rgb;
    }

    // encode using YUV 422H to "rg" free "ba" components for data
    outCol.rg = encodeYUV(fragcoord, outCol.rgb);

    // calculate "ba" data
    outCol.ba = getBA(lightmask, type, facetype, strength);

    return outCol;
}

vec4 getOutColor(vec4 color, vec4 light, vec2 lightmask, vec2 fragcoord, int facetype) {
    int alpha255 = int(round(color.a * 255.0));

    // get material type based on alpha
    int type = PBRTYPE_EMISSIVE * int(alpha255 >= EMISSMIN && alpha255 <= EMISSMAX) + 
               PBRTYPE_SUBSURFACE * int(alpha255 >= SUBSSMIN && alpha255 <= SUBSSMAX);

    if (type == PBRTYPE_EMISSIVE) {
        color.a = float(alpha255 - EMISSMIN) / float(EMISSMAX - EMISSMIN);
    }
    else if (type == PBRTYPE_SUBSURFACE) {
        color.a = float(alpha255 - SUBSSMIN) / float(SUBSSMAX - SUBSSMIN);
    }

    return getOutColorT(color, light, lightmask, fragcoord, facetype, type);
}

vec4 getOutColorSTDALock(vec4 color, vec4 light, vec2 lightmask, vec2 fragcoord) {
    vec4 outCol = vec4(1.0);

    outCol.rgb = color.rgb * light.rgb;

    // encode using YUV 422H to "rg" free "ba" components for data
    outCol.rg = encodeYUV(fragcoord, outCol.rgb);

    float b = max(smoothstep(5.0 / 15.0, 1.0, lightmask.x), 1.0 - smoothstep(5.0 / 15.0, 12.0 / 15.0, lightmask.y));
    outCol.b = float(int(round(b * 15.0)) * 16 + PBRTYPE_STANDARD) / 255.0;

    outCol.a = color.a;

    return outCol;
}

vec4 getOutColorPtclRGBLock(vec4 color, vec4 light, vec2 lightmask, int type) {
    vec4 outCol = color;
    outCol.rgb *= light.rgb;

    float a = max(smoothstep(5.0 / 15.0, 1.0, lightmask.x), 1.0 - smoothstep(5.0 / 15.0, 12.0 / 15.0, lightmask.y));
    outCol.a = float(int(round(max(color.a - 0.1, 0.0) / 0.9 * 31.0)) * 8 + int(round(a * 3.0)) * 2 + int(type == PBRTYPE_EMISSIVE)) / 255.0;

    return outCol;
}

bool isHand(float fogs, float foge) { // also includes panorama
    return fogs >= foge;
}

bool notPickup(mat4 mvm) {
    return mvm[0][0] == 1.0 && mvm[1][1] == 1.0 && mvm[2][2] == 1.0 && mvm[3][3] == 1.0 && mvm[0][2] == 0.0 && mvm[2][0] == 0.0;
}

bool notPickup2(mat4 mvm) {
    return mvm[0][1] == 0.0 && mvm[0][2] == 0.0 && mvm[0][3] == 0.0 && 
           mvm[1][0] == 0.0 && mvm[1][2] == 0.0 && mvm[1][3] == 0.0 && 
           mvm[2][0] == 0.0 && mvm[2][1] == 0.0 && mvm[2][3] == 0.0 && 
           mvm[3][0] == 0.0 && mvm[3][1] == 0.0 && mvm[3][2] == 0.0 && mvm[3][3] == 1.0;
}

int getDim(sampler2D lightmap) {
    vec4 lm = texelFetch(lightmap, ivec2(0), 0);
    return int(lm.r == lm.g && lm.g == lm.b) + 2 * int(lm.g > lm.r) + 3 * int(lm.r > lm.g);
}

float getFOV(mat4 ProjMat) {
    return atan(1.0, ProjMat[1][1]) * 360.0 / PI;
}

bool isGUI(mat4 ProjMat) {
    return ProjMat[2][3] == 0.0;
}

/*
 * Returns if rendering in the main menu background panorama
 * Checks the far clipping plane value so this should only be used with position_tex_color
 */
bool isPanorama(mat4 ProjMat) {
    float far = ProjMat[3][2] / (ProjMat[2][2] + 1);
    return far < 9.99996 && far > 9.99995;
}

// 10bit + 4x scalar hdr, alpha fully used
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

// 8x scalar hdr, 6bit alpha
vec4 encodeHDR_1(vec4 color) {
    color = clamp(color, 0.0, 8.0);
    int alpha = clamp(int(log2(max(max(max(color.r, color.g), color.b), 0.0001) * 0.9999)) + 1, 0, 3);
    return vec4(color.rgb / float(pow(2, alpha)), float(int(round(max(color.a, 0.0) * 63.0)) * 4 + alpha) / 255.0);
}

vec4 decodeHDR_1(vec4 color) {
    int alpha = int(round(color.a * 255.0));
    return vec4(color.rgb * float(pow(2, (alpha % 4))), float(alpha / 4) / 63.0);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}
#version 150

#define NUMCONTROLS 27
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define TINY 8e-8
#define PI 3.14159265359
#define LIGHT0_DIRECTION vec3(0.2, 1.0, -0.7) // Default light 0 direction everywhere except in inventory
#define LIGHT1_DIRECTION vec3(-0.2, 1.0, 0.7) // Default light 1 direction everywhere except in nether and inventory


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
[26] FogEnd
*/

// returns control pixel index or -1 if not control
int inControl(vec2 screenCoord, float screenWidth) {
    if (screenCoord.y < 1.0) {
        float index = floor(screenWidth / 2.0) + THRESH / 2.0;
        index = (screenCoord.x - index) / 2.0;
        if (fract(index) < THRESH && index < NUMCONTROLS && index >= 0) {
            return int(index);
        }
    }
    return -1;
}

// discards the current pixel if it is control
void discardControl(vec2 screenCoord, float screenWidth) {
    if (screenCoord.y < 1.0) {
        float index = floor(screenWidth / 2.0) + THRESH / 2.0;
        index = (screenCoord.x - index) / 2.0;
        if (fract(index) < THRESH && index < NUMCONTROLS && index >= 0) {
            discard;
        }
    }
}

// discard but for when ScreenSize is not given
void discardControlGLPos(vec2 screenCoord, vec4 glpos) {
    if (screenCoord.y < 1.0) {
        float screenWidth = round(screenCoord.x * 2.0 / (glpos.x / glpos.w + 1.0));
        float index = floor(screenWidth / 2.0) + THRESH / 2.0;
        index = (screenCoord.x - index) / 2.0;
        if (fract(index) < THRESH && index < NUMCONTROLS && index >= 0) {
            discard;
        }
    }
}

// get screen coordinates of a particular control index
vec2 getControl(int index, vec2 screenSize) {
    return vec2(floor(screenSize.x / 2.0) + float(index) * 2.0 + 0.5, 0.5) / screenSize;
}

int intmod(int i, int base) {
    return i - (i / base * base);
}

vec3 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = intmod(i, 256);
    i = i / 256;
    int g = intmod(i, 256);
    i = i / 256;
    int b = intmod(i, 128);
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

float getDirE(vec3 normal) {
    float dir = 3.0;
    float dotx = abs(dot(normal, vec3(1.0, 0.0, 0.0)));
    float doty = abs(dot(normal, vec3(0.0, 1.0, 0.0)));
    float dotz = abs(dot(normal, vec3(0.0, 0.0, 1.0)));
    if (dotx > doty && dotx > dotz) {
        dir = 1.0;
    } else if (dotz > doty && dotz > dotx) {
        dir = 2.0;
    }
    return dir;
}

float getDirB(vec3 normal) {
    float dir = 3.0;
    if (abs(normal.x) > 0.999) {
        dir = 1.0;
    } else if (abs(normal.z) > 0.999) {
        dir = 2.0;
    }
    return dir;
}

/*
 * Created by Onnowhere (https://github.com/onnowhere)
 * Utility functions for Minecraft core vertex shaders
 */

/*
 * Returns the FOV in degrees
 * Calculates using the fact that top/near = tan(theta / 2)
 */
float getFOV(mat4 ProjMat) {
    return atan(1.0, ProjMat[1][1]) * 114.591559;
}

/*
 * Returns if rendering in a GUI
 * In the GUI, near is 1000 and far is 3000, so -(far+near)/(far-near) = -2.0
 */
bool isGUI(mat4 ProjMat) {
    return ProjMat[3][2] == -2.0;
}

/*
 * Returns if rendering in the main menu background panorama
 * Checks the far clipping plane value so this should only be used with position_tex_color
 */
bool isPanorama(mat4 ProjMat) {
    float far = ProjMat[3][2] / (ProjMat[2][2] + 1);
    return far < 9.99996 && far > 9.99995;
}

/*
 * Returns if rendering in the nether given light directions
 * In the nether, the light directions are parallel but in opposite directions
 */
bool isNether(vec3 light0, vec3 light1) {
    return light0 == -light1;
}

/*
 * Returns camera to world space matrix given light directions
 * Creates matrix by comparing world space light directions to camera space light directions
 */
mat3 getWorldMat(vec3 light0, vec3 light1) {
    if (isNether(light0, light1)) {
        // Cannot determine matrix in the nether due to parallel light directions
        return mat3(1.0);
    }
    mat3 V = mat3(normalize(LIGHT0_DIRECTION), normalize(LIGHT1_DIRECTION), normalize(cross(LIGHT0_DIRECTION, LIGHT1_DIRECTION)));
    mat3 W = mat3(normalize(light0), normalize(light1), normalize(cross(light0, light1)));
    return W * inverse(V);
}

mat3 getInvWorldMat(vec3 light0, vec3 light1) {
    return transpose(getWorldMat(light0, light1));
}
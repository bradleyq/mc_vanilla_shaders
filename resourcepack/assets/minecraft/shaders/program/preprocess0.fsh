#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D PrevDataSampler;

uniform vec2 InSize;
uniform float FOVGuess;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define PROJFAR 1024.0
#define PI 3.14159265358979

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define FOG_WATER vec3(0.0 / 255.0, 37.0 / 255.0, 38.0 / 255.0)
#define FOG_WATER_END 80.0
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
#define FOG_DEFAULT_END 128.0
#define FOG_TARGET 0.2
#define FOG_DIST_MULT 2.5

#define FLAG_UNDERWATER 1<<0
#define FLAG_RAINING    1<<1


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
[26] FogStart -> Unused
[27] FogEnd -> FogLambda
[28] Dimension
[29] MiscFlags bit0:underwater bit1:raining 
[30]
[31]
*/

void main() {

    //simply decoding all the control data and constructing the sunDir, ProjMat, ModelViewMat
    vec4 outColor = vec4(0.0);
    vec2 start = getControl(0, InSize);
    vec2 inc = vec2(2.0 / InSize.x, 0.0);
    vec4 temp = texture(DiffuseSampler, start + 25.0 * inc);
    int index = int(gl_FragCoord.x);

    if (temp.a < 1.0) {

        /* Basic Matricies as follows
        tanVFOV = tan(FOVGuess * PI / 180.0 / 2.0);
        tanHFOV = tanVFOV * InSize.x / InSize.y;
        ProjMat = mat4(tanHFOV, 0.0,     0.0,                                               0.0,
                       0.0,     tanVFOV, 0.0,                                               0.0,
                       0.0,     0.0,    -(PROJFAR + PROJNEAR) / (PROJFAR - PROJNEAR),      -1.0,
                       0.0,     0.0,    -2.0 * (PROJFAR * PROJNEAR) / (PROJFAR - PROJNEAR), 0.0);
        ModelViewMat = mat4(1.0);
        */
        if (index == 3) {
            outColor = vec4(encodeFloat(FOVGuess * PI / 180.0 / 2.0), 0.0);
        }
        else if (index == 4) {
            outColor = vec4(encodeFloat(atan(tan(FOVGuess * PI / 180.0 / 2.0) * InSize.x / InSize.y)), 0.0);
        }
        else if (index == 11) {
            outColor = vec4(encodeFloat(-(PROJFAR + PROJNEAR) / (PROJFAR - PROJNEAR)), 0.0);
        }
        else if (index == 12) {
            outColor = vec4(encodeFloat(-1.0), 0.0);
        }
        else if (index == 15) {
            outColor = vec4(encodeFloat(-2.0 * (PROJFAR * PROJNEAR) / (PROJFAR - PROJNEAR)), 0.0);
        }
        else if (index == 16 || index == 20 || index == 24) {
            outColor = vec4(encodeFloat(1.0), 0.0);
        }
        // fog color
        else if (index == 25) {
            outColor = temp;
        }
        else if (index == 26) {
            outColor = vec4(encodeInt(0), 0.0);
        }
        else if (index == 27) {
            float range = FOG_DEFAULT_END;
            float lava = 1.0 - smoothstep(0.0, 0.05, length(temp.rgb - FOG_LAVA));
            range = mix(range, FOG_LAVA_END, lava);
            float snow = 1.0 - smoothstep(0.0, 0.05, length(temp.rgb - FOG_SNOW));
            range = mix(range, FOG_SNOW_END, snow);
            float blind = 1.0 - smoothstep(0.0, 0.05, length(temp.rgb - FOG_DARKNESS));
            range = mix(range, FOG_DARKNESS_END, blind);
            outColor = vec4(encodeFloat(log(FOG_TARGET) / float(-range)), 0.0);
        }
        else if (index == 28) {
            outColor = vec4(0.0);
            if(length(temp.rgb - FOG_END) < 0.005) {
                outColor = vec4(vec3(DIM_END), 1.0);
            }
        }
        else {
            outColor = vec4(0.0);
        }
    }
    else {
        if (index == 25) {
            int fstart = decodeInt(texture(DiffuseSampler, start + float(26) * inc).rgb);
            if (fstart == -8) {
                outColor = vec4(FOG_WATER, 1.0);
            } else {
                outColor = temp;
            }
        }
        else if (index == 29) {
            int currflags = int(texture(DiffuseSampler, start + float(29) * inc).r * 255.0);
            int fstart = decodeInt(texture(DiffuseSampler, start + float(26) * inc).rgb);
            if (fstart == -8) {
                currflags |= FLAG_UNDERWATER;
            }
            outColor = vec4(float(currflags) / 255.0, 0.0, 0.0, 1.0);
        }
        else if (index == 26) {
            outColor = vec4(encodeInt(0), 1.0);
        }
        else if (index == 27) {
            int fstart = decodeInt(texture(DiffuseSampler, start + float(26) * inc).rgb);
            int fend = int(FOG_WATER_END);
            if (fstart != -8) {
                fend = int(float(decodeInt(texture(DiffuseSampler, start + float(27) * inc).rgb)) * FOG_DIST_MULT);
            }
            outColor = vec4(encodeFloat(log(FOG_TARGET) / float(-fend)), 1.0);
        }
        else if (index <= 28) {
            outColor = texture(DiffuseSampler, start + float(index) * inc);
        }
    }
    fragColor = outColor;
}

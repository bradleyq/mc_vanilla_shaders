#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform vec2 OutSize;

in vec2 texCoord;
in vec3 sunDir;
in vec3 moonDir;
in mat4 Proj;
in mat4 ProjInv;
in float near;
in float far;
in float dim;
in float rain;
in float underWater;
in float sdu;
in float mdu;
in vec3 direct;
in vec3 ambient;
in vec3 backside;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

#define EMISSMULT 6.0
#define EMISSMULTP 1.0

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define TINT_WATER_DISTANCE 48.0

#define FLAG_UNDERWATER 1<<0

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

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

vec4 encodeHDR_1(vec4 color) {
    color = clamp(color, 0.0, 8.0);
    int alpha = clamp(int(log2(max(max(max(color.r, color.g), color.b), 0.0001) * 0.9999)) + 1, 0, 3);
    return vec4(color.rgb / float(pow(2, alpha)), float(int(round(max(color.a, 0.0) * 63.0)) * 4 + alpha) / 255.0);
}

vec4 decodeHDR_1(vec4 color) {
    int alpha = int(round(color.a * 255.0));
    return vec4(color.rgb * float(pow(2, (alpha % 4))), float(alpha / 4) / 63.0);
}

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

vec3 blend( vec3 dst, vec4 src ) {
    return mix(dst.rgb, src.rgb, src.a);
}

#define BLENDMULT_FACTOR 0.5

vec3 blendmult( vec3 dst, vec4 src) {
    return BLENDMULT_FACTOR * dst * mix(vec3(1.0), src.rgb, src.a) + (1.0 - BLENDMULT_FACTOR) * mix(dst.rgb, src.rgb, src.a);
}

void main() {
    vec4 outColor = texture(DiffuseSampler, texCoord);
  
    // sunDir exists
    if (outColor.a > 0.0 && length(sunDir) > 0.99) {
        vec2 normCoord = texCoord;
        vec2 scaledCoord = 2.0 * (normCoord - vec2(0.5));
        float depth = texture(DiffuseDepthSampler, normCoord).r;
        vec3 fragpos = backProject(vec4(scaledCoord, depth, 1.0)).xyz;
        int stype = int(outColor.a * 255.0) % 2;
        if (stype == 1) {
            stype = PBRTYPE_EMISSIVE;
        }
        else {
            stype = PBRTYPE_STANDARD;
        }
        float applyLight = clamp(float((int(outColor.a * 255.0) / 2) % 4) / 3.0, 0.0, 1.0);
        outColor.a = clamp(float(int(outColor.a * 255.0) / 8) * 0.9 / 31.0 + 0.1, 0.0, 1.0);

        // calculate final lighting color
        vec3 lightColor = ambient;
        vec3 normal_s = normalize(cross(sunDir, vec3(0.0, 0.0, 1.0)) + sunDir);
        vec3 normal_m = normalize(cross(moonDir, vec3(0.0, 0.0, 1.0)) + moonDir);
        lightColor += (direct - ambient) * clamp(dot(normal_s, sunDir), 0.0, 1.0); 
        lightColor += (backside - ambient) * clamp(dot(normal_m, moonDir), 0.0, 1.0); 

        // calculate emissive value
        float emission = 0.0;
        if (stype == PBRTYPE_EMISSIVE) {
            emission = EMISSMULTP;
        }

        // final shading
        outColor.rgb = outColor.rgb * (mix(lightColor, vec3(1.0), applyLight) + emission);

        if (underWater > 0.5) {
            outColor.rgb = mix(outColor.rgb, outColor.rgb * TINT_WATER, smoothstep(0, TINT_WATER_DISTANCE, length(fragpos)));
        }
         
        outColor = encodeHDR_1(outColor);
    }


    fragColor = outColor;
}

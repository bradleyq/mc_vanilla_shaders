#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform vec2 OutSize;
uniform float Range;

varying vec2 texCoord;
varying vec2 oneTexel;
varying vec3 normal;
varying vec3 tangent;
varying vec3 bitangent;
varying float aspectRatio;

#define BIGNEG -100000.0
#define NEAR 0.1
#define FAR 2048.0 
#define FUDGE 0.001
#define MAXSLOPE 30.0
#define MINSLOPE 0.03
#define MAXDELTA 3.0
#define FIXEDPOINT 100.0
#define MAXFOV 140.0 * FIXEDPOINT
#define MINFOV 30.0 * FIXEDPOINT
#define DEGCONVERT 360.0 / 3.14159268535 * FIXEDPOINT
#define SAMPLESTEP 5.0

int intmod(int i, int base) {
    return i - (i / base * base);
}

vec3 encodeInt(int i) {
    int r = intmod(i, 255);
    i = i / 255;
    int g = intmod(i, 255);
    i = i / 255;
    int b = intmod(i, 255);
    return vec3(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0);
}

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int num = 0;
    num += int(ivec.r);
    num += int(ivec.g) * 255;
    num += int(ivec.b) * 255 * 255;
    return num;
}
  
float LinearizeDepth(float depth) {
    float z = depth * 2.0 - 1.0;
    return (NEAR * FAR) / (FAR + NEAR - z * (FAR - NEAR));    
}

float depthLerp(sampler2D tex, vec2 coord) {
    vec2 resids = coord - floor(coord);
    coord = floor(coord) + 0.5;
    float deptha = LinearizeDepth(texture2D(tex, (coord) * oneTexel).r);
    float depthb = LinearizeDepth(texture2D(tex, (coord + vec2(1.0, 0.0)) * oneTexel).r);
    float depthc = LinearizeDepth(texture2D(tex, (coord + vec2(0.0, 1.0)) * oneTexel).r);
    float depthd = LinearizeDepth(texture2D(tex, (coord + vec2(1.0, 1.0)) * oneTexel).r);

    deptha = mix(deptha, depthb, resids.x);
    depthc = mix(depthc, depthd, resids.x);
    return mix(deptha, depthc, resids.y);
}

void main() {
    vec4 outColor = vec4(0.0);

    if (texCoord.x < 0.5 && texCoord.y < 0.5) {
        vec2 scaledCoord = texCoord * 2.0 - 0.5 * oneTexel;

        float tDotS = dot(tangent, vec3(0.0, 0.0, -1.0));
        float bDotS = dot(bitangent, vec3(0.0, 0.0, -1.0));
        vec2 projTangent = (tangent - tDotS * vec3(0.0, 0.0, -1.0)).xy;
        vec2 projBitangent = (bitangent - bDotS * vec3(0.0, 0.0, -1.0)).xy;
        float projTangentLen = length(projTangent);
        float projBitangentLen = length(projBitangent);
        projTangent = normalize(projTangent);
        projBitangent = normalize(projBitangent);
        float step = oneTexel.y * SAMPLESTEP;

        float depthM = LinearizeDepth(texture2D(DiffuseDepthSampler, scaledCoord.xy).r);
        float depth1 = LinearizeDepth(texture2D(DiffuseDepthSampler, scaledCoord.xy - vec2(0.0, step)).r);
        float depth2 = LinearizeDepth(texture2D(DiffuseDepthSampler, scaledCoord.xy + vec2(0.0, step)).r);
        float depth3 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 - projBitangent * SAMPLESTEP);
        float depth4 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 + projBitangent * SAMPLESTEP);
        float depth5 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 - projTangent * SAMPLESTEP);
        float depth6 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 + projTangent * SAMPLESTEP);
        float depthV1 = LinearizeDepth(texture2D(DiffuseDepthSampler, scaledCoord.xy + vec2(oneTexel.y, 0)).r);
        float depthV2 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 + vec2(projBitangent.y, -projBitangent.x));
        float depthV3 = depthLerp(DiffuseDepthSampler, scaledCoord.xy * OutSize - 0.5 + vec2(projTangent.y, -projTangent.x));

        if (((depth1 >= depthM - FUDGE && depthM + FUDGE >= depth2) || (depth1 <= depthM + FUDGE && depthM - FUDGE <= depth2)) 
        && ((depth3 >= depthM - FUDGE && depthM + FUDGE >= depth4) || (depth3 <= depthM + FUDGE && depthM - FUDGE <= depth4)) 
        && ((depth5 >= depthM - FUDGE && depthM + FUDGE >= depth6) || (depth5 <= depthM + FUDGE && depthM - FUDGE <= depth6)) 
        && depth1 < Range 
        && depth2 < Range
        && depth3 < Range
        && depth4 < Range
        && depth5 < Range
        && depth6 < Range
        && depthM < Range) {
            vec2 pos = (scaledCoord - 0.5) * vec2(aspectRatio, 1.0);
            float x1, x2, m, d1, d2;
            float fov1 = BIGNEG;
            float fov2 = BIGNEG;
            float fov3 = BIGNEG;

            if (abs(depth1 - depth2) > FUDGE && abs(depth1 - depth2) < MAXDELTA && abs(depthM - depthV1) < FUDGE) {
                m = normal.y / normal.z;
                if (abs(m) < MAXSLOPE && abs(m) > MINSLOPE) {
                    x1 = pos.y - step;
                    x2 = pos.y + step;
                    d1 = depth1;
                    d2 = depth2;
                    fov1 = m * (d1 * x1 - d2 * x2) / (d1 - d2);
                    fov1 = abs(atan(0.5, fov1)) * DEGCONVERT;
                }
            }

            if (abs(depth3 - depth4) > FUDGE && abs(depth3 - depth4) < MAXDELTA && abs(depthM - depthV2) < FUDGE) {
                m = -projBitangentLen / bDotS;
                if (abs(m) < MAXSLOPE && abs(m) > MINSLOPE) {
                    float distToAxis = dot(pos, projBitangent);
                    x1 = distToAxis - step;
                    x2 = distToAxis + step;
                    d1 = depth3;
                    d2 = depth4;
                    fov2 = m * (d1 * x1 - d2 * x2) / (d1 - d2);
                    fov2 = abs(atan(0.5, fov2)) * DEGCONVERT;
                }
            }

            if (abs(depth5 - depth6) > FUDGE && abs(depth5 - depth6) < MAXDELTA && abs(depthM - depthV3) < FUDGE) {
                m = -projTangentLen / tDotS;
                if (abs(m) < MAXSLOPE && abs(m) > MINSLOPE) {
                    float distToAxis = dot(pos, projTangent);
                    x1 = distToAxis - step;
                    x2 = distToAxis + step;
                    d1 = depth5;
                    d2 = depth6;
                    fov3 = m * (d1 * x1 - d2 * x2) / (d1 - d2);
                    fov3 = abs(atan(0.5, fov3)) * DEGCONVERT;
                }
            }

            float oldFov = clamp(float(decodeInt(texture2D(DiffuseSampler, vec2(0.5 / 16.0, 0.5)).rgb)), MINFOV, MAXFOV);

            float fov = fov1;
            float tbn = 3.0;
            if (abs(fov2 - oldFov) < abs(fov - oldFov)) {
                fov = fov2;
                tbn = 2.0;
            }
            if (abs(fov3 - oldFov) < abs(fov - oldFov)) {
                fov = fov3;
                tbn = 1.0;
            }

            if (fov > MINFOV && fov < MAXFOV) {
                outColor = vec4(encodeInt(int(floor(fov + 0.5))), (252.0 + tbn) / 255.0);
            }
        }
    }

    
    gl_FragColor = outColor;
}

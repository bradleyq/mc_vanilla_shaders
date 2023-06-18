#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D DiffuseTSampler;
uniform sampler2D EdgeSampler;
uniform sampler2D ShadingSampler;
uniform vec2 OutSize;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in vec4 fogColor;
in mat4 Proj;
in mat4 ProjInv;
in float near;
in float far;
in float dim;
in float rain;
in float underWater;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

#define EMISSMULT 6.0

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define TINT_WATER_DISTANCE 48.0

#define FLAG_UNDERWATER 1<<0

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define FACETYPE_Y 0
#define FACETYPE_X 1
#define FACETYPE_Z 2
#define FACETYPE_S 3

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

const vec2 poissonDisk[64] = vec2[64](
    vec2(-0.613392, 0.617481), vec2(0.170019, -0.040254), vec2(-0.299417, 0.791925), vec2(0.645680, 0.493210), vec2(-0.651784, 0.717887), vec2(0.421003, 0.027070), vec2(-0.817194, -0.271096), vec2(-0.705374, -0.668203), 
    vec2(0.977050, -0.108615), vec2(0.063326, 0.142369), vec2(0.203528, 0.214331), vec2(-0.667531, 0.326090), vec2(-0.098422, -0.295755), vec2(-0.885922, 0.215369), vec2(0.566637, 0.605213), vec2(0.039766, -0.396100),
    vec2(0.751946, 0.453352), vec2(0.078707, -0.715323), vec2(-0.075838, -0.529344), vec2(0.724479, -0.580798), vec2(0.222999, -0.215125), vec2(-0.467574, -0.405438), vec2(-0.248268, -0.814753), vec2(0.354411, -0.887570),
    vec2(0.175817, 0.382366), vec2(0.487472, -0.063082), vec2(-0.084078, 0.898312), vec2(0.488876, -0.783441), vec2(0.470016, 0.217933), vec2(-0.696890, -0.549791), vec2(-0.149693, 0.605762), vec2(0.034211, 0.979980),
    vec2(0.503098, -0.308878), vec2(-0.016205, -0.872921), vec2(0.385784, -0.393902), vec2(-0.146886, -0.859249), vec2(0.643361, 0.164098), vec2(0.634388, -0.049471), vec2(-0.688894, 0.007843), vec2(0.464034, -0.188818),
    vec2(-0.440840, 0.137486), vec2(0.364483, 0.511704), vec2(0.034028, 0.325968), vec2(0.099094, -0.308023), vec2(0.693960, -0.366253), vec2(0.678884, -0.204688), vec2(0.001801, 0.780328), vec2(0.145177, -0.898984),
    vec2(0.062655, -0.611866), vec2(0.315226, -0.604297), vec2(-0.780145, 0.486251), vec2(-0.371868, 0.882138), vec2(0.200476, 0.494430), vec2(-0.494552, -0.711051), vec2(0.612476, 0.705252), vec2(-0.578845, -0.768792),
    vec2(-0.772454, -0.090976), vec2(0.504440, 0.372295), vec2(0.155736, 0.065157), vec2(0.391522, 0.849605), vec2(-0.620106, -0.328104), vec2(0.789239, -0.419965), vec2(-0.545396, 0.538133), vec2(-0.178564, -0.596057));

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);

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


// tweak lighting color here
#define NOON_CLEAR vec3(1.2, 1.1, 0.95) * 4.0
#define NOONA_CLEAR vec3(0.55, 0.57, 0.7) * 2.5
#define NOONM_CLEAR vec3(0.45, 0.47, 0.6) * 2.5
#define EVENING_CLEAR vec3(1.3, 0.9, 0.5) * 2.5
#define EVENINGA_CLEAR vec3(0.55, 0.57, 0.65) * 1.5
#define EVENINGM_CLEAR vec3(0.4, 0.45, 0.6) * 1.5
#define NIGHT_CLEAR vec3(0.65, 0.65, 0.7) * 0.6
#define NIGHTA_CLEAR vec3(0.75, 0.75, 0.8) * 0.6
#define NIGHTM_CLEAR vec3(1.2, 1.3, 1.4) * 0.7

#define NOON_OVERCAST vec3(1.0, 1.05, 1.1) * 2.2
#define NOONA_OVERCAST vec3(0.65, 0.67, 0.7) * 2.2
#define NOONM_OVERCAST vec3(0.6, 0.6, 0.6) * 2.2
#define EVENING_OVERCAST vec3(1.0, 0.9, 0.85) * 1.0
#define EVENINGA_OVERCAST vec3(0.65, 0.67, 0.7) * 1.0
#define EVENINGM_OVERCAST vec3(0.55, 0.55, 0.55) * 1.0
#define NIGHT_OVERCAST vec3(0.65, 0.65, 0.65) * 0.6
#define NIGHTA_OVERCAST vec3(0.75, 0.75, 0.75) * 0.6
#define NIGHTM_OVERCAST vec3(1.0, 1.0, 1.0) * 0.6

#define END_CLEAR vec3(0.8, 0.85, 0.85)
#define ENDA_CLEAR vec3(0.9, 0.9, 0.95)
#define ENDM_CLEAR vec3(1.0, 0.9, 1.0)

#define NETHER_CLEAR vec3(1.15, 1.1, 1.0)
#define NETHERA_CLEAR vec3(1.1, 1.0, 1.0)
#define NETHERM_CLEAR vec3(1.0, 1.0, 1.0)

#define UNKNOWN_CLEAR vec3(0.95)
#define UNKNOWNA_CLEAR vec3(1.0)
#define UNKNOWNM_CLEAR vec3(1.05)

#define SNAPRANGE 100.0

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

#define pi 3.14159265359
#define invPi 1.0 / pi

#define zenithOffset -0.04
#define multiScatterPhaseClear 0.05
#define multiScatterPhaseOvercast 0.1
#define atmDensity 0.55

#define anisotropicIntensityClear 0.1 //Higher numbers result in more anisotropic scattering
#define anisotropicIntensityOvercast 0.3 //Higher numbers result in more anisotropic scattering

#define skyColorClear vec3(0.15, 0.50, 1.0) * (1.0 + anisotropicIntensityClear) //Make sure one of the conponents is never 0.0
#define skyColorOvercast vec3(0.5, 0.55, 0.6) * (1.0 + anisotropicIntensityOvercast) //Make sure one of the conponents is never 0.0
#define skyColorNightClear vec3(0.075, 0.1, 0.125)
#define skyColorNightOvercast vec3(0.07, 0.07, 0.085)

#define smooth(x) x*x*(3.0-2.0*x)

// #define zenithDensity(x) atmDensity / pow(max((x - zenithOffset) / (1.0 - zenithOffset), 0.008), 0.75)
#define zenithDensity(x, lx) atmDensity / pow(smoothClamp(((x - zenithOffset < 0.0 ? -(x - zenithOffset) * 0.2 : (x - zenithOffset) * 0.8)) / (1.0 - zenithOffset), 0.03 + clamp(0.03 * lx, 0.0, 1.0), 1.0), 0.75)

float smoothClamp(float x, float a, float b)
{
    return smoothstep(0., 1., (x - a)/(b - a))*(b - a) + a;
}

vec3 getSkyAbsorption(vec3 col, float density, float lpy) {
    
    vec3 absorption = col * -density * (1.0 + pow(clamp(-lpy, 0.0, 1.0), 2.0) * 8.0);
         absorption = exp2(absorption) * 2.0;
    
    return absorption;
}

float getSunPoint(vec3 p, vec3 lp) {
    return smoothstep(0.03, 0.01, distance(p, lp)) * 40.0;
}

float getMoonPoint(vec3 p, vec3 lp) {
    return smoothstep(0.05, 0.01, distance(p, lp)) * 1.0;
}

float getRayleigMultiplier(vec3 p, vec3 lp) {
    return 1.0 + pow(1.0 - clamp(distance(p, lp), 0.0, 1.0), 1.5) * pi * 0.5;
}

float getMie(vec3 p, vec3 lp) {
    float disk = clamp(1.0 - pow(max(distance(p, lp), 0.02), 0.08 / 1.718281828), 0.0, 1.0);
    
    return disk*disk*(3.0 - 2.0 * disk) * pi * 2.0;
}

float valNoise( vec2 p ){
    vec2 i = floor( p );
    vec2 f = fract( p );
	
	vec2 u = f*f*(3.0-2.0*f);

    return mix( mix( hash21( i + vec2(0.0,0.0) ), 
                     hash21( i + vec2(1.0,0.0) ), u.x),
                mix( hash21( i + vec2(0.0,1.0) ), 
                     hash21( i + vec2(1.0,1.0) ), u.x), u.y);
}

float gNoise( vec3 p ) {
    vec3 i = floor( p );
    vec3 f = fract( p );

    // cubic interpolant
    vec3 u = f*f*(3.0-2.0*f);   

    return mix( mix( mix( dot( hash33( i + vec3(0.0,0.0,0.0) ), f - vec3(0.0,0.0,0.0) ), 
                          dot( hash33( i + vec3(1.0,0.0,0.0) ), f - vec3(1.0,0.0,0.0) ), u.x),
                     mix( dot( hash33( i + vec3(0.0,1.0,0.0) ), f - vec3(0.0,1.0,0.0) ), 
                          dot( hash33( i + vec3(1.0,1.0,0.0) ), f - vec3(1.0,1.0,0.0) ), u.x), u.y),
                mix( mix( dot( hash33( i + vec3(0.0,0.0,1.0) ), f - vec3(0.0,0.0,1.0) ), 
                          dot( hash33( i + vec3(1.0,0.0,1.0) ), f - vec3(1.0,0.0,1.0) ), u.x),
                     mix( dot( hash33( i + vec3(0.0,1.0,1.0) ), f - vec3(0.0,1.0,1.0) ), 
                          dot( hash33( i + vec3(1.0,1.0,1.0) ), f - vec3(1.0,1.0,1.0) ), u.x), u.y), u.z );
}

vec3 starField(vec3 pos)
{
    vec3 col = 1.0 - vec3(valNoise(15.0 * (pos.xy + 0.05)), valNoise(20.0 * pos.yz), valNoise(25.0 * (pos.xz - 0.06)));
    col *= vec3(0.4, 0.8, 1.0);
    col = mix(col, vec3(1.0), 0.5);
    return col * smoothstep(0.5, 0.6, 1.5 * gNoise(128.0 * pos));
}

vec3 getAtmosphericScattering(vec3 srccol, vec3 p, vec3 lp, float rain, bool fog) {
    float zenith = zenithDensity(p.y, lp.y);
    float ly = lp.y < 0.0 ? lp.y * 0.3 : lp.y;
    float multiScatterPhase = mix(multiScatterPhaseClear, multiScatterPhaseOvercast, rain);
    float sunPointDistMult =  clamp(length(max(ly + multiScatterPhase - zenithOffset, 0.0)), 0.0, 1.0);
    
    float rayleighMult = getRayleigMultiplier(p, lp);
    vec3 sky = mix(skyColorClear, skyColorOvercast, rain);
    vec3 absorption = getSkyAbsorption(sky, zenith, lp.y);
    vec3 sunAbsorption = getSkyAbsorption(sky, zenithDensity(ly + multiScatterPhase, lp.y), lp.y);

    sky = sky * zenith * rayleighMult;

    vec3 totalSky = mix(sky * absorption, sky / (sky * 0.5 + 0.5), sunPointDistMult);
    if (!fog) {
        vec3 mie = getMie(p, lp) * sunAbsorption * sunAbsorption;
        mie += getSunPoint(p, lp) * absorption * clamp(1.2 - rain, 0.0, 1.0);
        totalSky += mie;
    }
    
    totalSky *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
    totalSky += srccol;

    float sdu = dot(lp, vec3(0.0, 1.0, 0.0));
    if (sdu < 0.0) {
        vec3 mlp = normalize(vec3(-lp.xy, 0.0));
        vec3 nightSky = (1.0 - 0.8 * abs(p.y < 0.0 ? -p.y * 0.5 : p.y)) * mix(skyColorNightClear, skyColorNightOvercast, rain);
        if (!fog) {
            nightSky += srccol + (1.0 - rain) * starField(vec3(dot(p, mlp), dot(p, vec3(0.0, 0.0, 1.0)), dot(p, normalize(cross(mlp, vec3(0.0, 0.0, 1.0))))));
        }
        totalSky = mix(nightSky, totalSky, clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0));
    }

    return totalSky;
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

vec4 decodeYUV(vec4 inCol, float sec) {
    vec4 outCol = vec4(1.0);
    vec3 yuv = vec3(0.0);
    if (int(gl_FragCoord.x) % 2 == 0) {
        yuv = vec3(inCol.xy, sec);
    }
    else {
        yuv = vec3(inCol.x, sec, inCol.y);
    }

    yuv.yz -= 0.5;
    outCol.r = yuv.x * 1.0 + yuv.y * 0.0 + yuv.z * 1.4;
    outCol.g = yuv.x * 1.0 + yuv.y * -0.343 + yuv.z * -0.711;
    outCol.b = yuv.x * 1.0 + yuv.y * 1.765 + yuv.z * 0.0;
    return outCol;
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
    float depth = decodeDepth(texture(DiffuseDepthSampler, texCoord));
    vec2 data = outColor.ba;
    bool isSky = linearizeDepth(depth) >= far - FUDGE;

    if (isSky && fogColor.a == 0.0) {
        outColor = vec4(fogColor.rgb, 1.0);
    }
    else {
        float sec;
        vec2 sec1 = texture(DiffuseSampler, texCoord + vec2(1.0, 0.0) * oneTexel).xy;
        vec2 sec2 = texture(DiffuseSampler, texCoord + vec2(-1.0, 0.0) * oneTexel).xy;
        
        sec = sec1.y;
        if ((abs(outColor.x - sec2.x) < abs(outColor.x - sec1.x) && texCoord.x > oneTexel.x) || texCoord.x >= 1.0 - oneTexel.x) {
            sec = sec2.y;
        }
        outColor = decodeYUV(outColor, sec);
    }

    // sunDir exists
    if (length(sunDir) > 0.99) {

        // only do lighting if not sky
        if (!isSky) {

            vec2 normCoord = texCoord;
            float minEdge = decodeFloat(texture(EdgeSampler, normCoord).rgb);
            float tmpEdge;
            int face = int(data.y * 255.0) % 4;
            int stype = int(data.x * 255.0) % 8;
            float applyLight = clamp(float(int(data.y * 255.0) / 4) / 63.0, 0.0, 1.0);
            float pbrStrength = 0.0;
            if (face == FACETYPE_S) {
                pbrStrength = clamp(float(int(data.x * 255.0) / 16) / 15.0, 0.0, 1.0);
                if (stype == PBRTYPE_STANDARD) {
                    applyLight = pbrStrength;
                }
            } 
            int tmpFace;

            vec2 candidates[8] = vec2[8](texCoord + vec2(-oneTexel.x, -oneTexel.y), texCoord + vec2(0.0, -oneTexel.y), 
                                            texCoord + vec2(oneTexel.x, -oneTexel.y), texCoord + vec2(oneTexel.x, 0.0),
                                            texCoord + vec2(oneTexel.x, oneTexel.y), texCoord + vec2(0.0, oneTexel.y),
                                            texCoord + vec2(-oneTexel.x, oneTexel.y), texCoord + vec2(-oneTexel.x, 0.0));
            
            for (int i = 0; i < 8; i += 1) {
                tmpEdge = decodeFloat(texture(EdgeSampler, candidates[i]).rgb);
                tmpFace = int(texture(DiffuseSampler, candidates[i]).w * 255.0) % 4;
                if (tmpEdge < minEdge && tmpFace == face) {
                    minEdge = tmpEdge;
                    normCoord = candidates[i];
                }
            } 

            // first calculate approximate surface normal using depth map
            depth = decodeDepth(texture(DiffuseDepthSampler, normCoord));
            float depth2 = decodeDepth(texture(DiffuseDepthSampler, normCoord + vec2(0.0, oneTexel.y)));
            float depth3 = decodeDepth(texture(DiffuseDepthSampler, normCoord + vec2(oneTexel.x, 0.0)));
            float depth4 = decodeDepth(texture(DiffuseDepthSampler, normCoord - vec2(0.0, oneTexel.y)));
            float depth5 = decodeDepth(texture(DiffuseDepthSampler, normCoord - vec2(oneTexel.x, 0.0)));

            vec2 scaledCoord = 2.0 * (normCoord - vec2(0.5));

            vec3 fragpos = backProject(vec4(scaledCoord, depth, 1.0)).xyz;
            vec3 p2 = backProject(vec4(scaledCoord + 2.0 * vec2(0.0, oneTexel.y), depth2, 1.0)).xyz;
            p2 = p2 - fragpos;
            vec3 p3 = backProject(vec4(scaledCoord + 2.0 * vec2(oneTexel.x, 0.0), depth3, 1.0)).xyz;
            p3 = p3 - fragpos;
            vec3 p4 = backProject(vec4(scaledCoord - 2.0 * vec2(0.0, oneTexel.y), depth4, 1.0)).xyz;
            p4 = p4 - fragpos;
            vec3 p5 = backProject(vec4(scaledCoord - 2.0 * vec2(oneTexel.x, 0.0), depth5, 1.0)).xyz;
            p5 = p5 - fragpos;
            if (face == 1.0 || face == 2.0) {
                float tmplen = length(p2.xz);
                if (tmplen > 1.0) {
                    p2.xz = vec2(0.0);
                }
                tmplen = length(p4.xz);
                if (tmplen > 1.0) {
                    p4.xz = vec2(0.0);
                }
            }
            vec3 normal = normalize(cross(p2, p3)) 
                        + normalize(cross(-p4, p3)) 
                        + normalize(cross(p2, -p5)) 
                        + normalize(cross(-p4, -p5));
            normal = normal == vec3(0.0) ? vec3(0.0, 1.0, 0.0) : normalize(-normal);

            normal = normal.x >  (1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(1.0, 0.0, 0.0) : normal;
            normal = normal.x < -(1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(-1.0, 0.0, 0.0) : normal;
            normal = normal.y >  (1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(0.0, 1.0, 0.0) : normal;
            normal = normal.y < -(1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(0.0, -1.0, 0.0) : normal;
            normal = normal.z >  (1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(0.0, 0.0, 1.0) : normal;
            normal = normal.z < -(1.0 - 0.05 * clamp(length(fragpos) / SNAPRANGE, 0.0, 1.0)) ? vec3(0.0, 0.0, -1.0) : normal;


            // get lighting color
            vec3 moonDir = normalize(vec3(-sunDir.xy, 0.0));
            float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
            float mdu = dot(vec3(0.0, 1.0, 0.0), moonDir);
            vec3 direct;
            vec3 ambient;
            vec3 backside;

            if (abs(dim - DIM_OVER) < 0.01) {
                vec3 evening = mix(EVENING_CLEAR, EVENING_OVERCAST, rain);
                vec3 evening_a = mix(EVENINGA_CLEAR, EVENINGA_OVERCAST, rain);
                vec3 evening_m = mix(EVENINGM_CLEAR, EVENINGM_OVERCAST, rain);
                if (sdu > 0.0) {
                    vec3 noon = mix(NOON_CLEAR, NOON_OVERCAST, rain);
                    vec3 noon_a = mix(NOONA_CLEAR, NOONA_OVERCAST, rain);
                    vec3 noon_m = mix(NOONM_CLEAR, NOONM_OVERCAST, rain);
                    direct = mix(evening, noon, sdu);
                    ambient = mix(evening_a, noon_a, sdu);
                    backside = mix(evening_m, noon_m, sdu);
                } else {
                    vec3 night = mix(NIGHT_CLEAR, NIGHT_OVERCAST, rain);
                    vec3 night_a = mix(NIGHTA_CLEAR, NIGHTA_OVERCAST, rain);
                    vec3 night_m = mix(NIGHTM_CLEAR, NIGHTM_OVERCAST, rain);
                    direct = mix(evening, night, clamp(pow(-sdu * 3.0, 0.5), 0.0, 1.0));
                    ambient = mix(evening_a, night_a, pow(-sdu, 0.5));
                    backside = mix(evening_m, night_m, pow(-sdu, 0.5));
                }
            }
            else if (abs(dim - DIM_END) < 0.01) {
                direct = END_CLEAR;
                ambient = ENDA_CLEAR;
                backside = ENDM_CLEAR;
            }
            else if (abs(dim - DIM_NETHER) < 0.01) {
                direct = NETHER_CLEAR;
                ambient = NETHERA_CLEAR;
                backside = NETHERM_CLEAR;
            }
            else {
                direct = UNKNOWN_CLEAR;
                ambient = UNKNOWNA_CLEAR;
                backside = UNKNOWNM_CLEAR;
            }


            // get ambient occlusion.
            vec3 ao = vec3(texture(ShadingSampler, texCoord).b);
            ao.rgb += vec3(hash21(gl_FragCoord.xy)) / 255.0;

            // get shadow / subsurface volume
            vec3 shade = vec3(texture(ShadingSampler, texCoord).r);
            vec3 shade_s = vec3(1.0);
            vec3 shade_m = vec3(1.0);

            vec3 eyedir = normalize(fragpos);
            float comp_bp_s = max(pow(dot(reflect(sunDir, normal), eyedir), 8.0), 0.0);
            float comp_bp_m = max(pow(dot(reflect(moonDir, normal), eyedir), 8.0), 0.0);
            float comp_diff_s = dot(normal, sunDir);
            float comp_diff_m = dot(normal, moonDir);

            // calculate final lighting color
            vec3 lightColor = ambient;

            if (face == FACETYPE_S && stype == PBRTYPE_SUBSURFACE) {
                float volume = texture(ShadingSampler, texCoord).g;
                float comp_sss_s = 0.0;
                float comp_sss_m = 0.0;
                if (sdu > 0.0) {
                    comp_sss_s = max(mix(pow(1.0 - volume, 2.0) - pow(length(scaledCoord), 4.0), comp_diff_s, 0.25), comp_diff_s);
                    shade_s = shade;
                }
                else {
                    comp_sss_m = max(mix(pow(1.0 - volume, 2.0) - pow(length(scaledCoord), 4.0), comp_diff_m, 0.25), comp_diff_m);
                    shade_m = shade;
                }
                lightColor += (direct - ambient) * clamp((comp_bp_s * 0.25 + comp_sss_s + 0.05) * shade_s, 0.0, 1.0); 
                lightColor += (backside - ambient) * clamp((comp_bp_m * 0.25 + comp_sss_m + 0.05) * shade_m, 0.0, 1.0); 
            }
            else {
                if (sdu > 0.0) {
                    shade_s = shade;
                }
                else {
                    shade_m = shade;
                }
                lightColor += (direct - ambient) * clamp((comp_bp_s * 0.25 + comp_diff_s + 0.05) * shade_s, 0.0, 1.0); 
                lightColor += (backside - ambient) * clamp((comp_bp_m * 0.25 + comp_diff_m + 0.05) * shade_m, 0.0, 1.0); 
            }

            // calculate emissive value
            float emission = 0.0;
            if (face == FACETYPE_S && stype == PBRTYPE_EMISSIVE) {
                emission = pbrStrength * EMISSMULT;
            }

            // final shading
            outColor.rgb = outColor.rgb * (mix(lightColor, vec3(1.0), applyLight) * ao + emission);

            if (underWater > 0.5) {
                outColor.rgb = mix(outColor.rgb, outColor.rgb * TINT_WATER, smoothstep(0, TINT_WATER_DISTANCE, length(fragpos)));
            }
        } 
        // if sky do atmosphere
        else if (abs(dim - DIM_OVER) < 0.01 && fogColor.a == 1.0) {
            vec2 scaledCoord = 2.0 * (texCoord - vec2(0.5));
            vec3 fragpos = normalize(backProject(vec4(scaledCoord, depth, 1.0)).xyz);
            vec3 color = getAtmosphericScattering(outColor.rgb, fragpos, sunDir, rain, false);
            color += vec3(hash21(gl_FragCoord.xy * 0.97 + 0.79)) / 255.0;

            outColor = vec4(color, 1.0);
        }

        vec4 translucent = texture(DiffuseTSampler, texCoord);
        if (translucent.a > 0.0) {
            if (int(translucent.a * 255.0) % 2 == 0) { // PBRTYPE_TRANSLUCENT
                outColor.rgb = blendmult(outColor.rgb, translucent);
            }
            else { // PBRTYPE_TEMISSIVE
                outColor.rgb += translucent.rgb * translucent.a * EMISSMULT;
            }
        }
    }

    outColor = encodeHDR_0(outColor);

    fragColor = outColor;
}

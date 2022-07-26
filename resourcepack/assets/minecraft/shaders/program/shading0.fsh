#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D EdgeSampler;
uniform vec2 OutSize;
uniform float Time;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in mat4 Proj;
in mat4 ProjInv;
in float near;
in float far;
in float fov;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

#define EMISS_MULT 1.5

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

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

#define AO_SAMPLES 32
#define AO_INTENSITY 3.0
#define AO_SCALE 2.5
#define AO_BIAS 0.15
#define AO_SAMPLE_RAD 0.5
#define AO_MAX_DISTANCE 3.0

#define MOD3 vec3(.1031,.11369,.13787)

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float doAmbientOcclusion(vec2 tcoord, vec2 uv, vec3 p, vec3 cnorm)
{
    vec3 diff = backProject(vec4(2.0 * (tcoord + uv - vec2(0.5)), decodeDepth(texture(DiffuseDepthSampler, tcoord + uv)), 1.0)).xyz - p;
    float l = length(diff);
    vec3 v = diff/(l + 0.0000001);
    float d = l*AO_SCALE;
    float ao = max(0.0,dot(cnorm,v)-AO_BIAS)*(1.0/(1.0+d));
    ao *= smoothstep(AO_MAX_DISTANCE,AO_MAX_DISTANCE * 0.5, l);
    return ao;

}

float spiralAO(vec2 uv, vec3 p, vec3 n, float rad)
{
    float goldenAngle = 2.4;
    float ao = 0.;
    float inv = 1. / float(AO_SAMPLES);
    float radius = 0.;

    float rotatePhase = hash12( uv*101. + Time * 69. ) * 6.28;
    float rStep = inv * rad;
    vec2 spiralUV;

    for (int i = 0; i < AO_SAMPLES; i++) {
        spiralUV.x = sin(rotatePhase);
        spiralUV.y = cos(rotatePhase);
        radius += rStep;
        ao += doAmbientOcclusion(uv, spiralUV * radius, p, n);
        rotatePhase += goldenAngle;
    }
    ao *= inv;
    return ao;
}

#define S_PENUMBRA 0.01
#define S_TAPS 2
#define S_SAMPLES 16
#define S_MAXREFINESAMPLES 1
#define S_STEPSIZE 0.12
#define S_STEPREFINE 0.4
#define S_STEPINCREASE 1.2
#define S_IGNORETHRESH 6.0
#define S_BIAS 0.001

int xorshift(int value) {
    // Xorshift*32
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

float luminance(vec3 rgb) {
    return  dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec2 Volumetric(vec3 fragpos, vec3 sundir, float fragdepth, float rand) {
    float distBias = length(fragpos) / 512.0;
    vec3 rayStart   = fragpos + abs(rand) * sundir * S_STEPSIZE;
    vec3 rayDir     = sundir;
    vec3 rayStep    = (S_STEPSIZE + S_STEPSIZE * 0.5 * (rand + 1.0)) * rayDir * (1.0 + distBias * 5.0);
    vec3 rayPos     = rayStart + rayStep;
    vec3 rayPrevPos = rayStart;
    vec3 rayRefine  = rayStep;

    vec4 pos    = vec4(0.0);
    float edge  = 0.0;
    float dtmp  = 0.0;
    float dist  = 0.0;
    float distmult = 1.0;
    float strength = 1.0;
    float strengthaccum = 0.0;
    bool enter = false;
    bool exit = false;
    float enterdist = S_IGNORETHRESH + 1.0;
    float enterdepth = 0.0;
    vec3 enterpos = vec3(0.0);
    vec3 exitpos = vec3(0.0);
    float volume = 0.0;

    for (int i = 0; i < S_SAMPLES; i += 1) {
        pos = Proj * vec4(rayPos.xyz, 1.0);
        pos.xyz /= pos.w;
        if (pos.x < -1.0 || pos.x > 1.0 || pos.y < -1.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) {
            exitpos = rayPos;
            exit = true;
            break;
        }
        dtmp = linearizeDepth(decodeDepth(texture(DiffuseDepthSampler, 0.5 * pos.xy + vec2(0.5))));
        dist = (linearizeDepth(pos.z) - dtmp);

        if (!enter && dist < distmult * max(length(rayStep) * pow(length(rayRefine), 0.25) * (1.0 + 2.0 * clamp(pow(abs(dot(normalize(fragpos), sunDir)), 4.0), 0.0, 1.0)), 0.2) && dist > distBias) {
            strength = strengthaccum;
            enterpos = rayPos;
            enterdist = dist;
            enterdepth = dtmp;
            rayStep = rayDir * S_STEPSIZE;
            enter = true;
        }
        else if (enter && dist < distBias) {
            exitpos = rayPos;
            exit = true;
            break;
        }

        if (dist > distBias) {
            distmult *= 1.3;
        }
        else if (distmult > 1.2) {
            distmult /= 1.3;
        }

        rayStep   *= S_STEPINCREASE;
        rayPrevPos = rayPos;
        rayRefine += rayStep;
        rayPos     = rayStart+rayRefine;

        strengthaccum += 1.0 / S_SAMPLES;
    }

    float interpt = length(fragpos - enterpos);

    if (enter && !exit && interpt < 2.0) {
        volume = 1.0;
    }
    else if (enter && exit && interpt < 2.0) {
        volume = max(length(exitpos - enterpos), volume);
    }

    if (enterdist > S_IGNORETHRESH || enterdepth > far * 0.5) {
        strength = 1.0;
    }
    return vec2(strength, volume);
}

void main() {

    vec2 poissonDisk[64];
    poissonDisk[0] = vec2(-0.613392, 0.617481);
    poissonDisk[1] = vec2(0.170019, -0.040254);
    poissonDisk[2] = vec2(-0.299417, 0.791925);
    poissonDisk[3] = vec2(0.645680, 0.493210);
    poissonDisk[4] = vec2(-0.651784, 0.717887);
    poissonDisk[5] = vec2(0.421003, 0.027070);
    poissonDisk[6] = vec2(-0.817194, -0.271096);
    poissonDisk[7] = vec2(-0.705374, -0.668203);
    poissonDisk[8] = vec2(0.977050, -0.108615);
    poissonDisk[9] = vec2(0.063326, 0.142369);
    poissonDisk[10] = vec2(0.203528, 0.214331);
    poissonDisk[11] = vec2(-0.667531, 0.326090);
    poissonDisk[12] = vec2(-0.098422, -0.295755);
    poissonDisk[13] = vec2(-0.885922, 0.215369);
    poissonDisk[14] = vec2(0.566637, 0.605213);
    poissonDisk[15] = vec2(0.039766, -0.396100);
    poissonDisk[16] = vec2(0.751946, 0.453352);
    poissonDisk[17] = vec2(0.078707, -0.715323);
    poissonDisk[18] = vec2(-0.075838, -0.529344);
    poissonDisk[19] = vec2(0.724479, -0.580798);
    poissonDisk[20] = vec2(0.222999, -0.215125);
    poissonDisk[21] = vec2(-0.467574, -0.405438);
    poissonDisk[22] = vec2(-0.248268, -0.814753);
    poissonDisk[23] = vec2(0.354411, -0.887570);
    poissonDisk[24] = vec2(0.175817, 0.382366);
    poissonDisk[25] = vec2(0.487472, -0.063082);
    poissonDisk[26] = vec2(-0.084078, 0.898312);
    poissonDisk[27] = vec2(0.488876, -0.783441);
    poissonDisk[28] = vec2(0.470016, 0.217933);
    poissonDisk[29] = vec2(-0.696890, -0.549791);
    poissonDisk[30] = vec2(-0.149693, 0.605762);
    poissonDisk[31] = vec2(0.034211, 0.979980);
    poissonDisk[32] = vec2(0.503098, -0.308878);
    poissonDisk[33] = vec2(-0.016205, -0.872921);
    poissonDisk[34] = vec2(0.385784, -0.393902);
    poissonDisk[35] = vec2(-0.146886, -0.859249);
    poissonDisk[36] = vec2(0.643361, 0.164098);
    poissonDisk[37] = vec2(0.634388, -0.049471);
    poissonDisk[38] = vec2(-0.688894, 0.007843);
    poissonDisk[39] = vec2(0.464034, -0.188818);
    poissonDisk[40] = vec2(-0.440840, 0.137486);
    poissonDisk[41] = vec2(0.364483, 0.511704);
    poissonDisk[42] = vec2(0.034028, 0.325968);
    poissonDisk[43] = vec2(0.099094, -0.308023);
    poissonDisk[44] = vec2(0.693960, -0.366253);
    poissonDisk[45] = vec2(0.678884, -0.204688);
    poissonDisk[46] = vec2(0.001801, 0.780328);
    poissonDisk[47] = vec2(0.145177, -0.898984);
    poissonDisk[48] = vec2(0.062655, -0.611866);
    poissonDisk[49] = vec2(0.315226, -0.604297);
    poissonDisk[50] = vec2(-0.780145, 0.486251);
    poissonDisk[51] = vec2(-0.371868, 0.882138);
    poissonDisk[52] = vec2(0.200476, 0.494430);
    poissonDisk[53] = vec2(-0.494552, -0.711051);
    poissonDisk[54] = vec2(0.612476, 0.705252);
    poissonDisk[55] = vec2(-0.578845, -0.768792);
    poissonDisk[56] = vec2(-0.772454, -0.090976);
    poissonDisk[57] = vec2(0.504440, 0.372295);
    poissonDisk[58] = vec2(0.155736, 0.065157);
    poissonDisk[59] = vec2(0.391522, 0.849605);
    poissonDisk[60] = vec2(-0.620106, -0.328104);
    poissonDisk[61] = vec2(0.789239, -0.419965);
    poissonDisk[62] = vec2(-0.545396, 0.538133);
    poissonDisk[63] = vec2(-0.178564, -0.596057);

    vec4 outColor = vec4(1.0);
    vec2 normCoord = texCoord;

    bool top = false;
    if (normCoord.y > 0.5) {
        normCoord.y -= 0.5;
        top = true;
    }
    normCoord.y = normCoord.y * 2.0 - oneTexel.y * 0.5;

    float depth = decodeDepth(texture(DiffuseDepthSampler, normCoord));
    bool isSky = linearizeDepth(depth) >= far - FUDGE;

    // sunDir exists
    if (length(sunDir) > 0.99) {

        // only do lighting if not sky
        if (!isSky) {
            vec3 moonDir = normalize(vec3(-sunDir.xy, 0.0));
            float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);

            if (top) {
                float minEdge = decodeFloat(texture(EdgeSampler, normCoord).rgb);
                float tmpEdge;

                vec2 candidates[8] = vec2[8](normCoord + vec2(-oneTexel.x, -oneTexel.y), normCoord + vec2(0.0, -oneTexel.y), 
                                normCoord + vec2(oneTexel.x, -oneTexel.y), normCoord + vec2(oneTexel.x, 0.0),
                                normCoord + vec2(oneTexel.x, oneTexel.y), normCoord + vec2(0.0, oneTexel.y),
                                normCoord + vec2(-oneTexel.x, oneTexel.y), normCoord + vec2(-oneTexel.x, 0.0));
                
                for (int i = 0; i < 8; i += 1) {
                    tmpEdge = decodeFloat(texture(EdgeSampler, candidates[i]).rgb);
                    if (tmpEdge < minEdge) {
                        minEdge = tmpEdge;
                        normCoord = candidates[i];
                    }
                } 

                vec2 scaledCoord = 2.0 * (normCoord - vec2(0.5));

                depth = decodeDepth(texture(DiffuseDepthSampler, normCoord));
                float depth2 = decodeDepth(texture(DiffuseDepthSampler, normCoord + vec2(0.0, oneTexel.y)));
                float depth3 = decodeDepth(texture(DiffuseDepthSampler, normCoord + vec2(oneTexel.x, 0.0)));

                vec3 fragpos = backProject(vec4(scaledCoord, depth, 1.0)).xyz;
                vec3 p2 = backProject(vec4(scaledCoord + 2.0 * vec2(0.0, oneTexel.y), depth2, 1.0)).xyz;
                p2 = p2 - fragpos;
                vec3 p3 = backProject(vec4(scaledCoord + 2.0 * vec2(oneTexel.x, 0.0), depth3, 1.0)).xyz;
                p3 = p3 - fragpos;
                vec3 normal = normalize(cross(p2, p3));
                normal = normal == vec3(0.0) ? vec3(0.0, 1.0, 0.0) : normalize(-normal);

                // calculate AO output.
                float rad = clamp(AO_SAMPLE_RAD/linearizeDepth(depth) * (70.0 / fov), 0.0005, 0.2);
                float ao = 1.0 - spiralAO(normCoord, fragpos, normal, rad) * AO_INTENSITY;
                outColor.rgb *= ao;
            }
            else {
                vec2 scaledCoord = 2.0 * (normCoord - vec2(0.5));
                vec3 fragpos = backProject(vec4(scaledCoord, depth, 1.0)).xyz;

                // calculate shadow.
                vec2 shade = vec2(0.0);
                for (int k = 0; k < S_TAPS; k += 1) {
                    int pindex = (k + int(gl_FragCoord.x * gl_FragCoord.y)) % 60;
                    shade += Volumetric(fragpos * (1.0 - S_BIAS), normalize(sunDir + S_PENUMBRA * vec3(poissonDisk[pindex].x, 0.0, poissonDisk[pindex].y)), linearizeDepth(depth), poissonDisk[pindex+1].x);
                }
                shade /= S_TAPS;
                shade.x = shade.x * shade.x * shade.x;
                shade.x = mix(1.0, shade.x, pow(max(sdu, 0.0), 0.25));
                outColor.rg = shade;
            }

        } 
    }

    fragColor = outColor;
}

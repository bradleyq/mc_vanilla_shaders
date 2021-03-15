#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D TranslucentHeightSampler;
uniform sampler2D TemporalSampler;

varying vec2 texCoord;
varying vec2 oneTexel;
varying vec3 approxNormal;
varying float aspectRatio;

#define APPROX_TAPS 6
#define APPROX_THRESH 0.5
#define APPROX_SCATTER 0.01
#define NORMAL_SCATTER 0.004
#define NORMRAD 5
#define FOV_FIXEDPOINT 100.0

#define near 0.00004882812 
#define far 1.0

#define SSR_TAPS 3
#define SSR_SAMPLES 30
#define SSR_MAXREFINESAMPLES 5
#define SSR_STEPSIZE 0.002
#define SSR_STEPREFINE 0.2
#define SSR_STEPINCREASE 1.2
#define SSR_IGNORETHRESH 0.001
#define SSR_BLURR 0.005
#define SSR_BLURTAPS 3
#define SSR_BLURSAMPLEOFFSET 17

#define HEIGHTMAP_PRECISION 1000000
#define HEIGHTMAP_SCALE 6.0
#define HEIGHTMAP_DECAY 48.0

float LinearizeDepth(float depth) 
{
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

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

float ditherGradNoise() {
  return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y));
}

float luminance(vec3 rgb) {
    return  dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec4 SSR(vec3 fragpos, float fragdepth, vec3 surfacenorm, vec4 skycol, vec4 approxreflection, vec2 randsamples[64], mat4 gbP) {
    vec3 rayStart   = fragpos.xyz;
    vec3 rayDir     = reflect(normalize(fragpos.xyz), vec3(surfacenorm.x, surfacenorm.y, surfacenorm.z));
    vec3 rayStep    = (SSR_STEPSIZE + SSR_STEPSIZE * 0.05 * (ditherGradNoise()-0.5)) * rayDir;
    vec3 rayPos     = rayStart + rayStep;
    vec3 rayPrevPos = rayStart;
    vec3 rayRefine  = rayStep;

    int refine  = 0;
    vec3 pos    = vec3(0.0);
    float edge  = 0.0;
    float dtmp  = 0.0;

    for (int i = 0; i < SSR_SAMPLES; i += 1) {
        pos = (gbP * vec4(rayPos.xyz, 1.0)).xyz;
        pos.xy /= rayPos.z;
        if (pos.x < -1.0 || pos.x > 1.0 || pos.y < -1.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) break;
        dtmp = LinearizeDepth(texture2D(DiffuseDepthSampler, pos.xy).r);
        float dist = abs(rayPos.z - dtmp);

        if (dtmp + SSR_IGNORETHRESH > fragdepth && dist < length(rayStep) * pow(length(rayRefine), 0.11) * 2.0) {
            refine++;
            if (refine >= SSR_MAXREFINESAMPLES)	break;
            rayRefine  -= rayStep;
            rayStep    *= SSR_STEPREFINE;
        }

        rayStep        *= SSR_STEPINCREASE;
        rayPrevPos      = rayPos;
        rayRefine      += rayStep;
        rayPos          = rayStart+rayRefine;

    }
    vec4 candidate = skycol;
    if (fragdepth < dtmp + SSR_IGNORETHRESH && pos.y <= 1.0) {
        vec3 colortmp = texture2D(DiffuseSampler, pos.xy).rgb;
        float count = 1.0;
        float dtmptmp = 0.0;
        vec2 postmp = vec2(0.0);
        for (int i = 0; i < SSR_BLURTAPS; i += 1) {
            postmp = pos.xy + randsamples[i + SSR_BLURSAMPLEOFFSET] * SSR_BLURR * vec2(1.0 / aspectRatio, 1.0);
            dtmptmp = LinearizeDepth(texture2D(DiffuseDepthSampler, postmp).r);
            if (abs(dtmp - dtmptmp) < SSR_IGNORETHRESH) {
                vec3 tmpcolortmp = texture2D(DiffuseSampler, postmp).rgb;
                float tmplum = luminance(tmpcolortmp);
                if (dtmptmp >= 0.999 && tmplum > 0.85) {
                    tmpcolortmp *= 1.0 + (tmplum - 0.8) * 10.0;
                }
                colortmp += tmpcolortmp;
                count += 1.0;
            }
        }
        colortmp /= count;
        candidate = mix(vec4(colortmp, 1.0), skycol, float(dtmp + SSR_IGNORETHRESH < 1.0) * clamp(pos.z * 1.1, 0.0, 1.0));
    }
    
    candidate = mix(candidate, approxreflection, clamp(pow(max(abs(pos.x - 0.5), abs(pos.y - 0.5)) * 2.0, 8.0), 0.0, 1.0));
    return candidate;
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

    vec4 outColor = vec4(0.0);
    vec4 color = texture2D(TranslucentSampler, texCoord);

    if (color.a > 0.0) {

        float FOVrad = float(decodeInt(texture2D(TemporalSampler, vec2(0.5 / 16.0, 0.5)).rgb)) / FOV_FIXEDPOINT / 360.0 * 3.1415926535;
        float cosFOVrad = cos(FOVrad);
        float tanFOVrad = tan(FOVrad);
        mat4 gbPI = mat4(2.0 * tanFOVrad * aspectRatio, 0.0,             0.0, 0.0,
                        0.0,                           2.0 * tanFOVrad, 0.0, 0.0,
                        0.0,                           0.0,             0.0, 0.0,
                        -tanFOVrad * aspectRatio,     -tanFOVrad,       1.0, 1.0);

        mat4 gbP = mat4(1.0 / (2.0 * tanFOVrad * aspectRatio), 0.0,               0.0, 0.0,
                        0.0,                             1.0 / (2.0 * tanFOVrad), 0.0, 0.0,
                        0.5,                             0.5,                     1.0, 0.0,
                        0.0,                             0.0,                     0.0, 1.0);

        float wdepth = texture2D(TranslucentDepthSampler, texCoord).r;
        float ldepth = LinearizeDepth(wdepth);
        float ldepth2 = LinearizeDepth(texture2D(TranslucentDepthSampler, texCoord + vec2(0.0, oneTexel.y)).r);
        float ldepth3 = LinearizeDepth(texture2D(TranslucentDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r);
        float ldepth4 = LinearizeDepth(texture2D(TranslucentDepthSampler, texCoord - vec2(0.0, oneTexel.y)).r);
        float ldepth5 = LinearizeDepth(texture2D(TranslucentDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r);
        float gdepth2 = LinearizeDepth(texture2D(DiffuseDepthSampler, texCoord + vec2(0.0, oneTexel.y)).r);
        float gdepth3 = LinearizeDepth(texture2D(DiffuseDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r);
        float gdepth4 = LinearizeDepth(texture2D(DiffuseDepthSampler, texCoord - vec2(0.0, oneTexel.y)).r);
        float gdepth5 = LinearizeDepth(texture2D(DiffuseDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r);
        vec4 reflection = vec4(0.0);
        vec4 sky = texture2D(TemporalSampler, vec2(9.5 / 16.0, 0.5));


        vec3 fragpos = (gbPI * vec4(texCoord, ldepth, 1.0)).xyz;
        fragpos *= ldepth;
        vec3 p2 = (gbPI * vec4(texCoord + vec2(0.0, oneTexel.y), ldepth2, 1.0)).xyz;
        p2 = p2 * ldepth2 - fragpos;
        vec3 p3 = (gbPI * vec4(texCoord + vec2(oneTexel.x, 0.0), ldepth3, 1.0)).xyz;
        p3 = p3 * ldepth3 - fragpos;
        vec3 p4 = (gbPI * vec4(texCoord - vec2(0.0, oneTexel.y), ldepth4, 1.0)).xyz;
        p4 = p4 * ldepth4 - fragpos;
        vec3 p5 = (gbPI * vec4(texCoord - vec2(oneTexel.x, 0.0), ldepth5, 1.0)).xyz;
        p5 = p5 * ldepth5 - fragpos;
        bool p2v = ldepth2 < gdepth2;
        bool p3v = ldepth3 < gdepth3;
        bool p4v = ldepth4 < gdepth4;
        bool p5v = ldepth5 < gdepth5;
        vec3 normal = normalize(cross(p2, p3)) * float(p2v && p3v) 
                    + normalize(cross(-p4, p3)) * float(p4v && p3v) 
                    + normalize(cross(p2, -p5)) * float(p2v && p5v) 
                    + normalize(cross(-p4, -p5)) * float(p4v && p5v);
        normal = normal == vec3(0.0) ? approxNormal : normalize(-normal);

        if (p2v && p3v) {
            float currH = decodeInt(texture2D(TranslucentHeightSampler, texCoord).rgb) / float(HEIGHTMAP_PRECISION);
            normal -= (normalize(p2) * (currH - decodeInt(texture2D(TranslucentHeightSampler, texCoord + vec2(0.0, oneTexel.y)).rgb) / float(HEIGHTMAP_PRECISION)) * HEIGHTMAP_SCALE
                     + normalize(p3) * (currH - decodeInt(texture2D(TranslucentHeightSampler, texCoord + vec2(oneTexel.x, 0.0)).rgb) / float(HEIGHTMAP_PRECISION)) * HEIGHTMAP_SCALE * aspectRatio) 
                     * pow(1.0 - ldepth, HEIGHTMAP_DECAY) * pow(dot(normal, normalize(fragpos)), 0.25);
            normal = normalize(normal);
        }
        
        float ndlsq = dot(normal, vec3(0.0, 0.0, 1.0));
        float horizon = clamp(ndlsq * 100000.0, -1.0, 1.0);
        ndlsq = ndlsq * ndlsq;

        if (abs(dot(normal, vec3(0.0, 1.0, 0.0))) > APPROX_THRESH) {
            vec2 reflectApprox = vec2(texCoord.x, 0.92 - texCoord.y + horizon * pow(clamp(ndlsq / (1.0 - cosFOVrad * cosFOVrad), 0.0, 1.0), 0.5));
            for (int i = 0; i < APPROX_TAPS; i++) {
                vec2 ratmp = clamp(reflectApprox + poissonDisk[i] * vec2(1.0 / aspectRatio, 1.0) * APPROX_SCATTER, vec2(0.0), vec2(1.0) - oneTexel / 2.0);
                float tdepth = texture2D(DiffuseDepthSampler, ratmp).r;
                if (tdepth > wdepth) {
                    reflection += vec4(texture2D(DiffuseSampler, ratmp).rgb, 1.0);
                }
            }
            reflection /= float(APPROX_TAPS);
            if (reflectApprox.y > 1.0) {
                reflection = mix(reflection, sky, clamp((reflectApprox.y - 1.0) * 20.0, 0.0, 1.0));
            }
        } else {
            reflection = sky;
        }

        vec4 r = vec4(0.0);
        for (int i = 0; i < SSR_TAPS; i += 1) {
            r += SSR(fragpos, ldepth, normalize(normal + NORMAL_SCATTER * (normalize(p2) * poissonDisk[i].x + normalize(p3) * poissonDisk[i].y)), sky, reflection, poissonDisk, gbP);
        }
        reflection = r / SSR_TAPS;
        
        float fresnel = exp(-35 * pow(dot(normalize(fragpos), normal), 2.0));
        float lookfresnel = clamp(exp(-25 * clamp(ndlsq * horizon, 0.0, 1.0) + 3.0), 0.0, 1.0);
        float lum = luminance(reflection.rgb);
        outColor = vec4(reflection.rgb, min(min(fresnel * lookfresnel * max(lum, 1.0), reflection.a), lum * 2.0));

    }

    gl_FragColor = outColor;
}

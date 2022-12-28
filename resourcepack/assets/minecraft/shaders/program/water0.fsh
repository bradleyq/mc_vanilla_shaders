#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in float near;
in float far;
in vec4 fogColor;
in float fogLambda;
in float underWater;
in float dim;
in float rain;
in float cave;
in float cosFOVsq;
in float aspectRatio;
in mat4 Proj;
in mat4 ProjInv;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

#define EMISSMULT 4.0

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define TINT_WATER_DISTANCE 48.0

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

vec4 decodeHDR_0(vec4 color) {
    int alpha = int(color.a * 255.0);
    return vec4(color.r + float((alpha >> 4) % 4), color.g + float((alpha >> 2) % 4), color.b + float(alpha % 4), 1.0);
}

vec4 encodeHDR_0(vec4 color) {
    int alpha = 3;
    color = clamp(color, 0.0, 4.0);
    vec3 colorFloor = clamp(floor(color.rgb), 0.0, 3.0);

    alpha = alpha << 2;
    alpha += int(colorFloor.r);
    alpha = alpha << 2;
    alpha += int(colorFloor.g);
    alpha = alpha << 2;
    alpha += int(colorFloor.b);

    return vec4(color.rgb - colorFloor, alpha / 255.0);
}

vec4 decodeHDR_1(vec4 color) {
    return vec4(color.rgb * (color.a + 1.0), 1.0);
}

vec4 encodeHDR_1(vec4 color) {
    float maxval = max(color.r, max(color.g, color.b));
    float mult = (maxval - 1.0) * 255.0 / 3.0;
    mult = clamp(ceil(mult), 0.0, 255.0);
    color.rgb = color.rgb * 255 / (mult / 255 * 3 + 1);
    color.rgb = round(color.rgb);
    return vec4(color.rgb, mult) / 255.0;
}


vec4 exponential_fog(vec4 inColor, vec4 fogColor, float depth, float lambda) {
    float fogValue = exp(-lambda * depth);
    return mix(fogColor, inColor, fogValue);
}

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

/*

    Non physical based atmospheric scattering made by robobo1221
    Site: http://www.robobo1221.net/shaders
    Shadertoy: http://www.shadertoy.com/user/robobo1221

*/

#define pi 3.14159265359
#define invPi 1.0 / pi

#define zenithOffset -0.04
#define multiScatterPhaseClear 0.05
#define multiScatterPhaseOvercast 0.1
#define atmDensity 0.55

#define anisotropicIntensityClear 0.1 //Higher numbers result in more anisotropic scattering
#define anisotropicIntensityOvercast 0.3 //Higher numbers result in more anisotropic scattering

#define skyColorClear vec3(0.2, 0.43, 1.0) * (1.0 + anisotropicIntensityClear) //Make sure one of the conponents is never 0.0
#define skyColorOvercast vec3(0.5, 0.55, 0.6) * (1.0 + anisotropicIntensityOvercast) //Make sure one of the conponents is never 0.0

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

vec3 getAtmosphericScattering(vec3 p, vec3 lp, float rain, bool fog) {
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
        mie += getSunPoint(p, lp) * absorption * clamp(1.02 - rain, 0.0, 1.0);
        totalSky += mie;
    }
    
    totalSky *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);

    return totalSky;
}

#define APPROX_TAPS 6
#define APPROX_THRESH 0.5
#define APPROX_SCATTER 0.01
#define NORMAL_SCATTER 0.004
#define NORMAL_SMOOTHING 0.01
#define NORMAL_DEPTH_REJECT 0.15
#define NORMRAD 5

#define SSR_TAPS 2
#define SSR_SAMPLES 40
#define SSR_MAXREFINESAMPLES 5
#define SSR_STEPSIZE 0.7
#define SSR_STEPREFINE 0.2
#define SSR_STEPINCREASE 1.25
#define SSR_IGNORETHRESH 2.0
#define SSR_INVALIDTHRESH 30.0
#define SSR_BLURR 0.01
#define SSR_BLURTAPS 3
#define SSR_BLURSAMPLEOFFSET 17

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

float ditherGradNoise() {
  return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y));
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec4 SSR(vec3 fragpos, vec3 dir, float fragdepth, vec3 surfacenorm, vec2 randsamples[64]) {
    vec3 rayStart   = fragpos;
    vec3 rayDir     = reflect(normalize(dir), surfacenorm);
    vec3 rayStep    = (SSR_STEPSIZE + SSR_STEPSIZE * 0.05 * (ditherGradNoise()-0.5)) * rayDir;
    vec3 rayPos     = rayStart + rayStep;
    vec3 rayPrevPos = rayStart;
    vec3 rayRefine  = rayStep;

    int refine  = 0;
    vec4 pos    = vec4(0.0);
    float edge  = 0.0;
    float dtmp  = 0.0;
    float dtmp_nolin = 0.0;
    float dist  = 0.0;
    bool oob = false;

    for (int i = 0; i < SSR_SAMPLES; i += 1) {
        pos = Proj * vec4(rayPos.xyz, 1.0);
        pos.xyz /= pos.w;
        if (pos.x < -1.0 || pos.x > 1.0 || pos.y < -1.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) {
            oob = true;
            break;
        }
        dtmp_nolin = texture(DiffuseDepthSampler, 0.5 * pos.xy + vec2(0.5)).r;
        dtmp = linearizeDepth(dtmp_nolin);
        dist = abs(linearizeDepth(pos.z) - dtmp);

        if (dist < length(rayStep) * pow(length(rayRefine), 0.25) * 3.0) {
            refine++;
            if (refine >= SSR_MAXREFINESAMPLES)    break;
            rayRefine  -= rayStep;
            rayStep    *= SSR_STEPREFINE;
        }

        rayStep        *= SSR_STEPINCREASE;
        rayPrevPos      = rayPos;
        rayRefine      += rayStep;
        rayPos          = rayStart+rayRefine;

    }

    float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
    float day = (sdu < 0.0) ? clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0) : 1.0;
    vec3 skycol = fogColor.rgb;
    if (underWater < 0.5 && dim == DIM_OVER) {
        skycol = getAtmosphericScattering(rayDir, sunDir, rain, false);

        vec3 moonDir = normalize(vec3(-sunDir.xy, 0.0));
        skycol += vec3(getMoonPoint(rayDir, moonDir)) * (1.0 - day) * (1.0 - rain);
        
        skycol = mix(skycol, fogColor.rgb, cave);
    }
    
    vec4 candidate = vec4(skycol, 1.0);
    if (!oob && dtmp + SSR_IGNORETHRESH > fragdepth && linearizeDepth(pos.z) < dtmp + SSR_INVALIDTHRESH) {
        vec3 colortmp = decodeHDR_0(texture(DiffuseSampler, 0.5 * pos.xy + vec2(0.5))).rgb;

        if (dtmp < far - FUDGE) {
            float count = 1.0;
            float dtmptmp = 0.0;
            vec2 postmp = vec2(0.0);

            for (int i = 0; i < SSR_BLURTAPS; i += 1) {
                postmp = pos.xy + randsamples[i + SSR_BLURSAMPLEOFFSET] * SSR_BLURR * vec2(1.0 / aspectRatio, 1.0);
                dtmptmp = linearizeDepth(texture(DiffuseDepthSampler, 0.5 * postmp + vec2(0.5)).r);
                if (abs(dtmp - dtmptmp) < SSR_IGNORETHRESH) {
                    vec3 tmpcolortmp = decodeHDR_0(texture(DiffuseSampler, 0.5 * postmp + vec2(0.5))).rgb;
                    colortmp += tmpcolortmp;
                    count += 1.0;
                }
            }
            
            colortmp /= count;
            candidate = vec4(colortmp, 1.0);

            vec3 fogcol = fogColor.rgb;
            if (underWater < 0.5 && dim == DIM_OVER) {
                rayDir.y = abs(rayDir.y * 0.5);
                rayDir = normalize(rayDir);
                fogcol = getAtmosphericScattering(rayDir, sunDir, rain, true);
                fogcol = mix(fogColor.rgb, fogcol, (1.0 - cave) * day);
            }
            candidate = exponential_fog(candidate, vec4(fogcol, 1.0), length(backProject(vec4(pos.xy, dtmp_nolin, 1.0)).xyz - fragpos), fogLambda);
        }
        else if (sdu < 0.0 && underWater < 0.5) {
            candidate = mix(vec4(colortmp, 1.0), candidate, day);
        }
    }

    candidate = mix(candidate, vec4(skycol, 1.0), clamp(pow(max(abs(pos.x), abs(pos.y)), 8.0), 0.0, 1.0));
    return candidate;
}

float getFresnel(float n0, float n1, float theta0) {
    float snell = n0 / n1 * sin(theta0);
    if (snell >= 1.0) {
        return 1.0;
    }

    float theta1 = asin(snell);
    float costheta0 = cos(theta0);
    float costheta1 = cos(theta1);
    float rs = (n0 * costheta0 - n1 * costheta1) / (n0 * costheta0 + n1 * costheta1);
    float rp = (n0 * costheta1 - n1 * costheta0) / (n0 * costheta1 + n1 * costheta0);

    return (rs * rs + rp * rp) / 2;
}

void main() {
    vec4 outColor = vec4(0.0);
    vec4 color = texture(TranslucentSampler, texCoord);

    if (color.a > 0.0) {
        float ldepth = texture(TranslucentDepthSampler, texCoord).r;
        float lineardepth = linearizeDepth(ldepth);
        float ldepth2 = (texture(TranslucentDepthSampler, texCoord + vec2(0.0, oneTexel.y)).r);
        float ldepth3 = (texture(TranslucentDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r);
        float ldepth4 = (texture(TranslucentDepthSampler, texCoord - vec2(0.0, oneTexel.y)).r);
        float ldepth5 = (texture(TranslucentDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r);
        float gdepth2 = (texture(DiffuseDepthSampler, texCoord + vec2(0.0, oneTexel.y)).r);
        float gdepth3 = (texture(DiffuseDepthSampler, texCoord + vec2(oneTexel.x, 0.0)).r);
        float gdepth4 = (texture(DiffuseDepthSampler, texCoord - vec2(0.0, oneTexel.y)).r);
        float gdepth5 = (texture(DiffuseDepthSampler, texCoord - vec2(oneTexel.x, 0.0)).r);


        vec2 scaledCoord = 2.0 * (texCoord - vec2(0.5));
        vec3 fragpos = backProject(vec4(scaledCoord, ldepth, 1.0)).xyz;

        vec3 p2 = backProject(vec4(scaledCoord + 2.0 * vec2(0.0, oneTexel.y), ldepth2, 1.0)).xyz;
        p2 = p2 - fragpos;
        vec3 p3 = backProject(vec4(scaledCoord + 2.0 * vec2(oneTexel.x, 0.0), ldepth3, 1.0)).xyz;
        p3 = p3 - fragpos;
        vec3 p4 = backProject(vec4(scaledCoord - 2.0 * vec2(0.0, oneTexel.y), ldepth4, 1.0)).xyz;
        p4 = p4 - fragpos;
        vec3 p5 = backProject(vec4(scaledCoord - 2.0 * vec2(oneTexel.x, 0.0), ldepth5, 1.0)).xyz;
        p5 = p5 - fragpos;

        bool p2v = ldepth2 < gdepth2 && length(p2) < length(NORMAL_DEPTH_REJECT * fragpos);
        bool p3v = ldepth3 < gdepth3 && length(p3) < length(NORMAL_DEPTH_REJECT * fragpos);
        bool p4v = ldepth4 < gdepth4 && length(p4) < length(NORMAL_DEPTH_REJECT * fragpos);
        bool p5v = ldepth5 < gdepth5 && length(p5) < length(NORMAL_DEPTH_REJECT * fragpos);

        vec3 normal = normalize(cross(p2, p3)) * float(p2v && p3v) 
                    + normalize(cross(-p4, p3)) * float(p4v && p3v) 
                    + normalize(cross(p2, -p5)) * float(p2v && p5v) 
                    + normalize(cross(-p4, -p5)) * float(p4v && p5v);

        normal = normal == vec3(0.0) ? vec3(0.0, 1.0, 0.0) : normalize(-normal);

        float smoothing = min(NORMAL_SMOOTHING, texCoord.y);
        if (int(color.a * 255.0) % 2 == 0) {
            float ldepth6 = (texture(TranslucentDepthSampler, texCoord + NORMAL_SMOOTHING * vec2(0.0, 1.0)).r);
            float ldepth7 = (texture(TranslucentDepthSampler, texCoord + NORMAL_SMOOTHING * vec2(aspectRatio, 0.0)).r);
            float ldepth8 = (texture(TranslucentDepthSampler, texCoord - smoothing * vec2(0.0, 1.0)).r);
            float ldepth9 = (texture(TranslucentDepthSampler, texCoord - NORMAL_SMOOTHING * vec2(aspectRatio, 0.0)).r);
            float gdepth6 = (texture(DiffuseDepthSampler, texCoord + NORMAL_SMOOTHING * vec2(0.0, 1.0)).r);
            float gdepth7 = (texture(DiffuseDepthSampler, texCoord + NORMAL_SMOOTHING * vec2(aspectRatio, 0.0)).r);
            float gdepth8 = (texture(DiffuseDepthSampler, texCoord - smoothing * vec2(0.0, 1.0)).r);
            float gdepth9 = (texture(DiffuseDepthSampler, texCoord - NORMAL_SMOOTHING * vec2(aspectRatio, 0.0)).r);

            vec3 p6 = backProject(vec4(scaledCoord + 2.0 * NORMAL_SMOOTHING * vec2(0.0, 1.0), ldepth6, 1.0)).xyz;
            p6 = p6 - fragpos;
            vec3 p7 = backProject(vec4(scaledCoord + 2.0 * NORMAL_SMOOTHING * vec2(aspectRatio, 0.0), ldepth7, 1.0)).xyz;
            p7 = p7 - fragpos;
            vec3 p8 = backProject(vec4(scaledCoord - 2.0 * smoothing * vec2(0.0, 1.0), ldepth8, 1.0)).xyz;
            p8 = p8 - fragpos;
            vec3 p9 = backProject(vec4(scaledCoord - 2.0 * NORMAL_SMOOTHING * vec2(aspectRatio, 0.0), ldepth9, 1.0)).xyz;
            p9 = p9 - fragpos;

            bool p6v = ldepth6 < gdepth6 && length(p6) < length(NORMAL_DEPTH_REJECT * fragpos);
            bool p7v = ldepth7 < gdepth7 && length(p7) < length(NORMAL_DEPTH_REJECT * fragpos);
            bool p8v = ldepth8 < gdepth8 && length(p8) < length(NORMAL_DEPTH_REJECT * fragpos);
            bool p9v = ldepth9 < gdepth9 && length(p9) < length(NORMAL_DEPTH_REJECT * fragpos);

            vec3 normalsmooth = normalize(cross(p6, p7)) * float(p6v && p7v) 
                              + normalize(cross(-p8, p7)) * float(p8v && p7v) 
                              + normalize(cross(p6, -p9)) * float(p6v && p9v) 
                              + normalize(cross(-p8, -p9)) * float(p8v && p9v);

            if (normalsmooth != vec3(0.0)) {
                normalsmooth = normalize(-normalsmooth);
                normal = mix(normal, normalsmooth, smoothstep(0.9, 0.95, dot(normal, normalsmooth)) * (1.0 - clamp(lineardepth / (far / 4.0), 0.0, 1.0)));
            }
        }

        vec4 reflection = vec4(0.0);

        vec4 r = vec4(0.0);
        for (int i = 0; i < SSR_TAPS; i += 1) {
            r += SSR(fragpos, backProject(vec4(scaledCoord, 1.0, 1.0)).xyz, linearizeDepth(ldepth), normalize(normal + NORMAL_SCATTER * (normalize(p2) * poissonDisk[i].x + normalize(p3) * poissonDisk[i].y)), poissonDisk);
        }
        reflection = r / SSR_TAPS;

        float fresnel = 0.0;
        float indexair = 1.0;
        float indexwater = 1.333;
        float theta = acos(dot(normalize(fragpos), -normal));
        if (underWater > 0.5) {
            fresnel = getFresnel(indexwater, indexair, theta);
        }
        else {
            fresnel = getFresnel(indexair, indexwater, theta);
        }
        
        #define HDR_LIMIT 4.0
        float maxelem = max(reflection.r, max(reflection.g, reflection.b));
        if (maxelem > HDR_LIMIT) {
            float scale = min(maxelem / HDR_LIMIT, 1.0 / (fresnel + 0.001));
            reflection.rgb /= scale;
            fresnel *= scale;
        }
        fresnel = min(fresnel, reflection.a);

        // fresnel = 1.0;

        int alphaval = int(round(clamp(fresnel, 0.0, 1.0) * 127.0));

        if (maxelem > 2.0) {
            alphaval += 128;
            reflection.rgb /= 4.0;
        }
        else {
            reflection.rgb /= 2.0;
        }

        outColor = vec4(reflection.rgb, float(alphaval) / 255.0);
    }

    fragColor = vec4(outColor.rgb, outColor.a);
}

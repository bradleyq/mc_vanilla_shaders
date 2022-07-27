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
in float raining;
in float cosFOVsq;
in float aspectRatio;
in mat4 Proj;
in mat4 ProjInv;

out vec4 fragColor;

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
#define multiScatterPhase 0.05
#define atmDensity 0.4

#define anisotropicIntensity 0.0 //Higher numbers result in more anisotropic scattering

#define skyColor vec3(0.3, 0.53, 1.0) * (1.0 + anisotropicIntensity) //Make sure one of the conponents is never 0.0

#define smooth(x) x*x*(3.0-2.0*x)

#define zenithDensity(x) atmDensity / pow(smoothClamp(((x - zenithOffset < 0.0 ? -(x - zenithOffset) * 0.4 : x - zenithOffset)) / (1.0 - zenithOffset), 0.03, 1.0), 0.75)

float smoothClamp(float x, float a, float b)
{
    return smoothstep(0., 1., (x - a)/(b - a))*(b - a) + a;
}

vec3 getSkyAbsorption(vec3 col, float density, float lpy) {
	
	vec3 absorption = col * -density * (1.0 + pow(clamp(-lpy, 0.0, 1.0), 2.0) * 8.0);
	     absorption = exp2(absorption) * 2.0;
	
	return absorption;
}

float getSunPoint(vec3 p, vec3 lp){
	return smoothstep(0.04, 0.0, distance(p, lp)) * 30.0;
}

float getRayleigMultiplier(vec3 p, vec3 lp){
	return 1.0 + pow(1.0 - clamp(distance(p, lp), 0.0, 1.0), 2.0) * pi * 0.5;
}

float getMie(vec3 p, vec3 lp){
	float disk = clamp(1.0 - pow(distance(p, lp), mix(0.3, 0.13, exp(max(lp.y, 0.0)) - 1.0) / 1.718281828), 0.0, 1.0);
	
	return disk*disk*(3.0 - 2.0 * disk) * 2.0 * pi;
}

vec3 getAtmosphericScattering(vec3 p, vec3 lp, bool fog){
	float zenith = zenithDensity(p.y);
    float ly = lp.y < 0.0 ? lp.y * 0.3 : lp.y;
	float sunPointDistMult =  clamp(length(max(ly + multiScatterPhase - zenithOffset, 0.0)), 0.0, 1.0);
	
	float rayleighMult = getRayleigMultiplier(p, lp);
	
	vec3 absorption = getSkyAbsorption(skyColor, zenith, lp.y);
    vec3 sunAbsorption = getSkyAbsorption(skyColor, zenithDensity(ly + multiScatterPhase), lp.y);
	vec3 sky = skyColor * zenith * rayleighMult;
	vec3 mie = getMie(p, lp) * sunAbsorption;
	if (!fog) mie += getSunPoint(p, lp) * absorption;
	
	vec3 totalSky = mix(sky * absorption, sky / (sky * 0.5 + 0.5), sunPointDistMult);
         totalSky += mie;
	     totalSky *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return totalSky;
}

vec3 jodieReinhardTonemap(vec3 c){
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);

    return mix(c / (l + 1.0), tc, tc);
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

float luminance(vec3 rgb) {
    return  dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

vec4 SSR(vec3 fragpos, vec3 dir, float fragdepth, vec3 surfacenorm, vec4 approxreflection, vec2 randsamples[64]) {
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

    for (int i = 0; i < SSR_SAMPLES; i += 1) {
        pos = Proj * vec4(rayPos.xyz, 1.0);
        pos.xyz /= pos.w;
        if (pos.x < -1.0 || pos.x > 1.0 || pos.y < -1.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) break;
        dtmp_nolin = texture(DiffuseDepthSampler, 0.5 * pos.xy + vec2(0.5)).r;
        dtmp = linearizeDepth(dtmp_nolin);
        dist = abs(linearizeDepth(pos.z) - dtmp);

        if (dist < length(rayStep) * pow(length(rayRefine), 0.25) * 3.0) {
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

    vec3 skycol = fogColor.rgb;
    if (underWater < 0.5) {
        skycol = getAtmosphericScattering(rayDir, sunDir, false) * pi;
        skycol = jodieReinhardTonemap(skycol);
        skycol = pow(skycol, vec3(2.2)); //Back to linear
    }
    
    vec4 candidate = vec4(skycol, 1.0);
    if (dtmp + SSR_IGNORETHRESH > fragdepth && linearizeDepth(pos.z) < dtmp + SSR_INVALIDTHRESH && pos.y <= 1.0 && dtmp < far * 0.5) {
        vec3 colortmp = texture(DiffuseSampler, 0.5 * pos.xy + vec2(0.5)).rgb;
        rayDir.y = abs(rayDir.y * 0.2);
        rayDir = normalize(rayDir);
        vec3 fogcol = fogColor.rgb;
        if (underWater < 0.5) {
            fogcol = getAtmosphericScattering(rayDir, sunDir, true) * pi;
            fogcol = jodieReinhardTonemap(fogcol);
            fogcol = pow(fogcol, vec3(2.2)); //Back to linear
        }
        float count = 1.0;
        float dtmptmp = 0.0;
        vec2 postmp = vec2(0.0);
        for (int i = 0; i < SSR_BLURTAPS; i += 1) {
            postmp = pos.xy + randsamples[i + SSR_BLURSAMPLEOFFSET] * SSR_BLURR * vec2(1.0 / aspectRatio, 1.0);
            dtmptmp = linearizeDepth(texture(DiffuseDepthSampler, 0.5 * postmp + vec2(0.5)).r);
            if (abs(dtmp - dtmptmp) < SSR_IGNORETHRESH) {
                vec3 tmpcolortmp = texture(DiffuseSampler, 0.5 * postmp + vec2(0.5)).rgb;
                colortmp += tmpcolortmp;
                count += 1.0;
            }
        }
        colortmp /= count;
        candidate = vec4(colortmp, 1.0);
        candidate = exponential_fog(candidate, vec4(fogcol, 1.0), length(backProject(vec4(pos.xy, dtmp_nolin, 1.0)).xyz - fragpos), fogLambda);
    }
    
    candidate = mix(candidate, vec4(skycol, 1.0), clamp(pow(max(abs(pos.x), abs(pos.y)), 8.0), 0.0, 1.0));
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
            r += SSR(fragpos, backProject(vec4(scaledCoord, 1.0, 1.0)).xyz, linearizeDepth(ldepth), normalize(normal + NORMAL_SCATTER * (normalize(p2) * poissonDisk[i].x + normalize(p3) * poissonDisk[i].y)), reflection, poissonDisk);
        }
        reflection = r / SSR_TAPS;
        
        float fresnel = clamp(exp((underWater * 15 - 25) * pow(dot(normalize(fragpos), normal), 2.0)) * (0.8 + 7.2 * underWater), 0.0, 1.0);
        float lumdiff = pow(max(luminance(reflection.rgb) * (1.5 + 7.0 * underWater) - luminance(color.rgb), 0.0), 0.25);
        outColor = vec4(reflection.rgb, min(min(fresnel * lumdiff, 1.0), reflection.a));
    }

    fragColor = vec4(outColor.rgb, outColor.a);
}

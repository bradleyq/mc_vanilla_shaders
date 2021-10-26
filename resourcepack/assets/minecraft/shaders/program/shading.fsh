#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D EdgeSampler;
uniform vec2 OutSize;
uniform float Time;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in mat4 ProjInv;
in float near;
in float far;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define NUMCONTROLS 27
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

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

vec4 getNotControl(sampler2D inSampler, vec2 coords, bool inctrl) {
    if (inctrl) {
        return (texture(inSampler, coords - vec2(oneTexel.x, 0.0)) + texture(inSampler, coords + vec2(oneTexel.x, 0.0)) + texture(inSampler, coords + vec2(0.0, oneTexel.y))) / 3.0;
    } else {
        return texture(inSampler, coords);
    }
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
//     uint exponent = uint(clamp(ceil(log2(abs(val))) + 31, 0.0, 63.0));
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

// tweak lighting color here
#define NOON vec3(1.2, 1.2, 1.2)
#define NOONA vec3(0.5, 0.55, 0.75)
#define NOONM vec3(0.45, 0.5, 0.7)
#define EVENING vec3(1.35, 1.0, 0.5)
#define EVENINGA vec3(0.69, 0.75, 1.0)
#define EVENINGM vec3(0.69, 0.75, 1.0)
#define NIGHT vec3(0.8, 0.8, 0.8)
#define NIGHTA vec3(0.9, 0.9, 0.9)
#define NIGHTM vec3(1.1, 1.3, 1.4)
#define SNAPRANGE 100.0

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
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
#define density 0.5

#define anisotropicIntensity 0.0 //Higher numbers result in more anisotropic scattering

#define skyColor vec3(0.3, 0.53, 1.0) * (1.0 + anisotropicIntensity) //Make sure one of the conponents is never 0.0

#define smooth(x) x*x*(3.0-2.0*x)
#define zenithDensity(x) density / pow(max((x - zenithOffset) / (1.0 - zenithOffset), 0.008), 0.75)

vec3 getSkyAbsorption(vec3 x, float y){
	
	vec3 absorption = x * -y;
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
	
	vec3 absorption = getSkyAbsorption(skyColor, zenith);
    vec3 sunAbsorption = getSkyAbsorption(skyColor, zenithDensity(ly + multiScatterPhase));
	vec3 sky = skyColor * zenith * rayleighMult;
	vec3 mie = getMie(p, lp) * sunAbsorption;
	if (!fog) mie += getSunPoint(p, lp) * absorption;
	
	vec3 totalSky = mix(sky * absorption, sky / (sky + 0.5), sunPointDistMult);
         totalSky += mie;
	     totalSky *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
    totalSky = mix(totalSky, vec3(0.1, 0.15, 0.33), clamp(pow(-p.y + zenithOffset, 0.5), 0.0, 1.0));
	return totalSky;
}

vec3 jodieReinhardTonemap(vec3 c){
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);

    return mix(c / (l + 1.0), tc, tc);
}

int xorshift(int value) {
    // Xorshift*32
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return value;
}

float PRNG(int seed) {
    seed = xorshift(seed);
    return abs(fract(float(seed) / 3141.592653));
}

#define SAMPLES 64
#define INTENSITY 3.0
#define SCALE 2.5
#define BIAS 0.1
#define SAMPLE_RAD 0.5
#define MAX_DISTANCE 3.0

#define MOD3 vec3(.1031,.11369,.13787)

float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float doAmbientOcclusion(vec2 tcoord, vec2 uv, vec3 p, vec3 cnorm)
{
    vec3 diff = backProject(vec4(2.0 * (tcoord + uv - vec2(0.5)), texture(DiffuseDepthSampler, tcoord + uv).r, 1.0)).xyz - p;
    float l = length(diff);
    vec3 v = diff/(l + 0.0000001);
    float d = l*SCALE;
    float ao = max(0.0,dot(cnorm,v)-BIAS)*(1.0/(1.0+d));
    ao *= smoothstep(MAX_DISTANCE,MAX_DISTANCE * 0.5, l);
    return ao;

}

float spiralAO(vec2 uv, vec3 p, vec3 n, float rad)
{
    float goldenAngle = 2.4;
    float ao = 0.;
    float inv = 1. / float(SAMPLES);
    float radius = 0.;

    float rotatePhase = hash12( uv*101. + Time * 69. ) * 6.28;
    float rStep = inv * rad;
    vec2 spiralUV;

    for (int i = 0; i < SAMPLES; i++) {
        spiralUV.x = sin(rotatePhase);
        spiralUV.y = cos(rotatePhase);
        radius += rStep;
        ao += doAmbientOcclusion(uv, spiralUV * radius, p, n);
        rotatePhase += goldenAngle;
    }
    ao *= inv;
    return ao;
}

void main() {
    bool inctrl = inControl(texCoord * OutSize, OutSize.x) > -1;

    fragColor = texture(DiffuseSampler, texCoord);
    float depth = texture(DiffuseDepthSampler, texCoord).r;

    // not control and sunDir exists
    if (!inctrl && length(sunDir) > 0.99) {

        // only do lighting if not sky
        if (linearizeDepth(depth) < far - FUDGE) {

            vec2 normCoord = texCoord;
            float minEdge = decodeFloat(texture(EdgeSampler, normCoord).rgb);
            float tmpEdge;
            int face = int(fragColor.a * 255.0) % 4;
            float applyLight = clamp(float(int(fragColor.a * 255.0) / 4) / 63.0, 0.0, 1.0);
            int tmpFace;

            vec2 candidates[8] = vec2[8](texCoord + vec2(-oneTexel.x, -oneTexel.y), texCoord + vec2(0.0, -oneTexel.y), 
                                            texCoord + vec2(oneTexel.x, -oneTexel.y), texCoord + vec2(oneTexel.x, 0.0),
                                            texCoord + vec2(oneTexel.x, oneTexel.y), texCoord + vec2(0.0, oneTexel.y),
                                            texCoord + vec2(-oneTexel.x, oneTexel.y), texCoord + vec2(-oneTexel.x, 0.0));
            
            for (int i = 0; i < 8; i += 1) {
                tmpEdge = decodeFloat(texture(EdgeSampler, candidates[i]).rgb);
                tmpFace = int(texture(DiffuseSampler, candidates[i]).a * 255.0) % 4;
                if (tmpEdge < minEdge && tmpFace == face) {
                    minEdge = tmpEdge;
                    normCoord = candidates[i];
                }
            } 

            // first calculate approximate surface normal using depth map
            depth = getNotControl(DiffuseDepthSampler, normCoord, inControl(normCoord * OutSize, OutSize.x) > -1).r;
            float depth2 = getNotControl(DiffuseDepthSampler, normCoord + vec2(0.0, oneTexel.y), inControl((normCoord + vec2(0.0, oneTexel.y)) * OutSize, OutSize.x) > -1).r;
            float depth3 = getNotControl(DiffuseDepthSampler, normCoord + vec2(oneTexel.x, 0.0), inControl((normCoord + vec2(oneTexel.x, 0.0)) * OutSize, OutSize.x) > -1).r;
            float depth4 = getNotControl(DiffuseDepthSampler, normCoord - vec2(0.0, oneTexel.y), inControl((normCoord - vec2(0.0, oneTexel.y)) * OutSize, OutSize.x) > -1).r;
            float depth5 = getNotControl(DiffuseDepthSampler, normCoord - vec2(oneTexel.x, 0.0), inControl((normCoord - vec2(oneTexel.x, 0.0)) * OutSize, OutSize.x) > -1).r;

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

            // use cos between sunDir to determine light and ambient colors
            vec3 moonDir = normalize(vec3(-sunDir.xy, 0.0));
            float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
            float mdu = dot(vec3(0.0, 1.0, 0.0), moonDir);
            vec3 direct;
            vec3 ambient;
            vec3 backside;
            if (sdu > 0.0) {
                direct = mix(EVENING, NOON, sdu);
                ambient = mix(EVENINGA, NOONA, sdu);
                backside = mix(EVENINGM, NOONM, sdu);
            } else {
                direct = mix(EVENING, NIGHT, pow(-sdu * 2.0, 0.5));
                ambient = mix(EVENINGA, NIGHTA, pow(-sdu, 0.3));
                backside = mix(EVENINGM, NIGHTM, pow(-sdu, 0.3));
            }

            // apply ambient occlusion.
            float rad = SAMPLE_RAD/linearizeDepth(depth);
            float ao = 1.0 - spiralAO(normCoord, fragpos, normal, rad) * INTENSITY;
            fragColor.rgb *= ao;

            // apply lighting color. not quite standard diffuse light equation since the blocks are already "pre-lit"
            vec3 lightColor = ambient;
            lightColor += (direct - ambient) * clamp(dot(normal, sunDir) + 0.05, 0.0, 1.0); 
            lightColor += (backside - ambient) * clamp(dot(normal, moonDir), 0.0, 1.0); 
            fragColor.rgb = mix(fragColor.rgb * mix(lightColor, vec3(1.0), applyLight), lightColor, 0.0);

            // desaturate bright pixels for more realistic feel
            fragColor.rgb = mix(fragColor.rgb, vec3(length(fragColor.rgb)/sqrt(3.0)), luma(fragColor.rgb) * 0.5);

            // fragColor.r = float(face == 0);
            // fragColor.rgb = vec3(float(face) / 3.0);
            // fragColor.rgb = vec3(linearizeDepth(depth) / (far / 3.0));
            // fragColor.rgb = 0.5 * (normal + vec3(1.0));
            // fragColor.a = 1.0;
        } 
        // if sky do atmosphere
        else {
            float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);

            vec2 scaledCoord = 2.0 * (texCoord - vec2(0.5));
            vec3 fragpos = normalize(backProject(vec4(scaledCoord, depth, 1.0)).xyz);
            vec3 color = getAtmosphericScattering(fragpos, sunDir, false) * pi;
            color = jodieReinhardTonemap(color);
            color = pow(color, vec3(2.2)); //Back to linear
            color += vec3(PRNG(int(gl_FragCoord.x) + int(gl_FragCoord.y) * int(OutSize.x))) / 255.0;

            if (sdu > 0.0) {
                fragColor = vec4(color, 1.0 );
            } else {
                fragColor.rgb = mix(fragColor.rgb, color, clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0));
            }

        }
    }
}

#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ReflectionSampler;
uniform sampler2D ItemEntitySampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D ParticlesWeatherSampler;
uniform sampler2D ParticlesWeatherDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;
uniform vec2 OutSize;
uniform float Time;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in vec4 fogColor;
in mat4 ProjInv;
in float near;
in float far;
in float fogLambda;
in float underWater;
in float rain;
in float cave;

#define NUM_LAYERS 5

#define DEFAULT 0u
#define FOGFADE 1u
#define BLENDMULT 2u
#define BLENDADD 4u
#define HASREFLECT 8u

vec4 color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
uint op_layers[NUM_LAYERS];
int index_layers[NUM_LAYERS] = int[NUM_LAYERS](0, 1 ,2, 3, 4);
int active_layers = 0;

out vec4 fragColor;

vec2 scaledCoord = 2.0 * (texCoord - vec2(0.5));

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

vec4 encodeDepth(float depth) {
    return encodeUInt(floatBitsToUint(depth)); 
}

float decodeDepth(vec4 depth) {
    return uintBitsToFloat(decodeUInt(depth)); 
}

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

vec4 exponential_fog(vec4 inColor, vec4 fogColor, float depth, float lambda) {
    float fogValue = exp(-lambda * depth * (1.0 + 0.05 * PRNG(int(gl_FragCoord.x * 1.983) + int(gl_FragCoord.y * 890.261) * int(OutSize.x))));
    return mix(fogColor, inColor, fogValue);
}

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

float euclidianDistance(vec4 coord) {
    return length(backProject(coord).xyz);
}

float cylindricalDistance(vec4 coord) {
    return length(backProject(coord).xz);
}

void try_insert( vec4 color, float depth, uint op ) {
    if (color.a == 0.0) {
        return;
    }

    color_layers[active_layers] = color;
    depth_layers[active_layers] = depth;
    op_layers[active_layers] = op;

    int jj = active_layers++;
    int ii = jj - 1;
    while (jj > 0 && depth > depth_layers[index_layers[ii]]) {
        int indexTemp = index_layers[ii];
        index_layers[ii] = index_layers[jj];
        index_layers[jj] = indexTemp;

        jj = ii--;
    }
}

vec3 blend(vec3 dst, vec4 src) {
    return mix(dst.rgb, src.rgb, src.a);
    // return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

#define BLENDMULT_FACTOR 0.5

vec3 blendmult(vec3 dst, vec4 src) {
    return BLENDMULT_FACTOR * dst * mix(vec3(1.0), src.rgb, src.a) + (1.0 - BLENDMULT_FACTOR) * mix(dst.rgb, src.rgb, src.a);
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

void main() {
    vec3 fragpos = backProject(vec4(scaledCoord, 1.0, 1.0)).xyz;
    fragpos = normalize(fragpos);
    fragpos.y = abs(fragpos.y * 0.5);
    fragpos = normalize(fragpos);

    vec4 calculatedFog = vec4(1.0);

    vec3 color = getAtmosphericScattering(fragpos, sunDir, rain, true);

    float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
    if (underWater > 0.5) {
        calculatedFog.rgb = fogColor.rgb;
    }
    else {
        float condition = (1.0 - cave);
        if (sdu < 0.0) {
            condition *= clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0);
        }
        calculatedFog.rgb = mix(fogColor.rgb, color, condition);
    }

    op_layers[0] = DEFAULT;
    // crumbling, beacon_beam, leash, entity_translucent_emissive(warden glow), chunk border lines
    depth_layers[0] = decodeDepth(texture(DiffuseDepthSampler, texCoord));
    vec4 diffusecolor = vec4(decodeHDR_0(texture(DiffuseSampler, texCoord)).rgb, 1.0 );
    float currdist = euclidianDistance(vec4(scaledCoord, depth_layers[0], 1.0));
    bool sky = depth_layers[0] == 1.0;

    color_layers[0] = diffusecolor;
    active_layers = 1;
    vec4 reflection = texture(ReflectionSampler, texCoord);
    if (reflection.a >= 128.0 / 255.0) {
        reflection.rgb *= 4.0;
    }
    else {
        reflection.rgb *= 2.0;
    }
    reflection.a = float(int(reflection.a * 255.0) % 128) / 127.0;

    float clouddepth = texture(CloudsDepthSampler, texCoord).r;
    vec4 cloudcolor = texture(CloudsSampler, texCoord);
    try_insert( exponential_fog(cloudcolor, vec4(cloudcolor.rgb, 0.0), cylindricalDistance(vec4(scaledCoord, clouddepth, 1.0)), fogLambda * 2.0), clouddepth, FOGFADE);

    // glass, water
    try_insert( texture(TranslucentSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, BLENDMULT | HASREFLECT); 
    // rain, snow, tripwire
    try_insert( texture(ParticlesWeatherSampler, texCoord), decodeDepth(texture(ParticlesWeatherDepthSampler, texCoord)), DEFAULT);
    // translucent_moving_block, lines, item_entity_translucent_cull
    try_insert( texture(ItemEntitySampler, texCoord), texture(ItemEntityDepthSampler, texCoord).r, DEFAULT);

    vec4 texelAccum = vec4(color_layers[index_layers[0]].rgb, 1.0);
    for ( int ii = 1; ii < active_layers; ++ii ) {
        int index = index_layers[ii];
        uint flags = op_layers[index];
        float dist = euclidianDistance(vec4(scaledCoord, depth_layers[index], 1.0));
        // if (!sky || underWater > 0.5) texelAccum = exponential_fog(texelAccum, calculatedFog, currdist - dist, fogLambda); // sky will be shaded by water fog
        if (!sky) texelAccum = exponential_fog(texelAccum, calculatedFog, currdist - dist, fogLambda);
        if ((flags & FOGFADE) == 0u) {
            sky = false;
            currdist = dist;
        }
        if ((flags & BLENDMULT) > 0u) {
            texelAccum.rgb = blendmult( texelAccum.rgb, color_layers[index]);
        } else {
            texelAccum.rgb = blend( texelAccum.rgb, color_layers[index]);
        }
        if ((flags & HASREFLECT) > 0u) {
            texelAccum.rgb = mix(texelAccum.rgb, reflection.rgb, reflection.a);
        }
    }

    if (!sky || underWater > 0.5) {
        texelAccum = exponential_fog(texelAccum, calculatedFog, currdist, fogLambda);
    }

    fragColor = encodeHDR_0(texelAccum);
}
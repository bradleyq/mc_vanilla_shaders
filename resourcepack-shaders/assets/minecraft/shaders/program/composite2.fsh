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
in float dim;

#define DIM_UNKNOWN 0
#define DIM_OVER 1
#define DIM_END 2
#define DIM_NETHER 3

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

float hash21(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
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

vec4 exponential_fog(vec4 inColor, vec4 fogColor, float depth, float lambda) {
    float fogValue = exp(-lambda * depth * (1.0 + 0.05 * hash21(gl_FragCoord.xy * vec2(0.983, 1.261))));
    return mix(fogColor, inColor, fogValue);
}

float linearstep(float edge0, float edge1, float x)
{
    return  clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

vec4 linear_fog(vec4 inColor, float vertexDistance, float fogStart, float fogEnd, vec4 fogColor) {
    if (vertexDistance <= fogStart) {
        return inColor;
    }

    float fogValue = vertexDistance < fogEnd ? linearstep(fogStart, fogEnd, vertexDistance) : 1.0;
    return mix(inColor, fogColor, fogValue);
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
}

#define BLENDMULT_FACTOR 0.5

vec3 blendmult(vec3 dst, vec4 src) {
    return BLENDMULT_FACTOR * dst * mix(vec3(1.0), src.rgb, src.a) + (1.0 - BLENDMULT_FACTOR) * mix(dst.rgb, src.rgb, src.a);
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
        vec3 nightSky = (1.0 - 0.8 * p.y) * mix(skyColorNightClear, skyColorNightOvercast, rain);
        if (!fog) {
            nightSky += srccol + (1.0 - rain) * starField(vec3(dot(p, mlp), dot(p, vec3(0.0, 0.0, 1.0)), dot(p, normalize(cross(mlp, vec3(0.0, 0.0, 1.0))))));
        }
        totalSky = mix(nightSky, totalSky, clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0));
    }

    return totalSky;
}

void main() {
    vec3 fragpos = backProject(vec4(scaledCoord, 1.0, 1.0)).xyz;
    float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);

    fragpos = normalize(fragpos);
    fragpos.y = abs(fragpos.y * 0.5);
    fragpos = normalize(fragpos);

    vec4 calculatedFog = vec4(1.0);

    vec3 color = fogColor.rgb;
    if (abs(dim - DIM_OVER) < 0.01 && fogColor.a == 1.0) {
        color = getAtmosphericScattering(vec3(0.0), fragpos, sunDir, rain, true);
    }
    if (underWater > 0.5) {
        calculatedFog.rgb = fogColor.rgb;
    }
    else {
        calculatedFog.rgb = mix(color, fogColor.rgb, cave);
    }

    op_layers[0] = DEFAULT;
    // crumbling, beacon_beam, leash, entity_translucent_emissive(warden glow), chunk border lines
    depth_layers[0] = decodeDepth(texture(DiffuseDepthSampler, texCoord));
    vec4 diffusecolor = vec4(decodeHDR_0(texture(DiffuseSampler, texCoord)).rgb, 1.0);
    float currdist = euclidianDistance(vec4(scaledCoord, depth_layers[0], 1.0));
    bool sky = depth_layers[0] == 1.0;

    color_layers[0] = diffusecolor;
    active_layers = 1;
    vec4 reflection = texture(ReflectionSampler, texCoord);
    if (reflection.a >= 128.0 / 255.0) {
        reflection.rgb *= 12.0;
    }
    else {
        reflection.rgb *= 3.0;
    }
    reflection.a = float(int(reflection.a * 255.0) % 128) / 127.0;

    float clouddepth = texture(CloudsDepthSampler, texCoord).r;
    vec4 cloudcolor = texture(CloudsSampler, texCoord);
    if( cloudcolor.a > 0.0) {
        cloudcolor.a *= 1.0 - rain;
        if (abs(dim - DIM_OVER) < 0.01 && fogColor.a == 1.0) {
            cloudcolor.rgb = mix(getAtmosphericScattering(vec3(0.0), vec3(fragpos.x, -fragpos.y, fragpos.z), sunDir, rain, true), 
                                getAtmosphericScattering(vec3(0.0), sunDir, sunDir, rain, false) / 20.0 + vec3(0.2), cloudcolor.r);
        }
        else {
            cloudcolor.rgb = fogColor.rgb;
        }

        cloudcolor.rgb = mix(cloudcolor.rgb, normalize(vec3(1.0)) * length(cloudcolor.rgb), 0.4);
        try_insert( linear_fog(cloudcolor, cylindricalDistance(vec4(scaledCoord, clouddepth, 1.0)), 400.0, 512.0, vec4(cloudcolor.rgb, 0.0)), clouddepth, FOGFADE);
    }

    // glass, water
    try_insert( texture(TranslucentSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, BLENDMULT | HASREFLECT); 
    // rain, snow, tripwire
    try_insert( decodeHDR_1(texture(ParticlesWeatherSampler, texCoord)), decodeDepth(texture(ParticlesWeatherDepthSampler, texCoord)), DEFAULT);
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
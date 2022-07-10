#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
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
in float fogStart;
in float fogEnd;
in float underWater;
in float raining;

#define NUM_LAYERS 5

#define DEFAULT 0u
#define FOGFADE 1u
#define BLENDMULT 2u
#define BLENDADD 4u

vec4 color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
uint op_layers[NUM_LAYERS];
int index_layers[NUM_LAYERS] = int[NUM_LAYERS](0, 1 ,2, 3, 4);
int active_layers = 0;

out vec4 fragColor;

vec2 scaledCoord = 2.0 * (texCoord - vec2(0.5));

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

vec4 linear_fog_real(vec4 inColor, float vertexDistance, float fogStart, float fogEnd, vec4 fogColor) {
    if (vertexDistance <= fogStart) {
        return inColor;
    }

    float fogValue = vertexDistance < fogEnd ? smoothstep(fogStart, fogEnd, vertexDistance) : 1.0;
    return mix(inColor, fogColor, fogValue);
}

vec4 backProject(vec4 vec) {
    vec4 tmp = ProjInv * vec;
    return tmp / tmp.w;
}

void try_insert( vec4 color, float depth, vec4 fog, float fstart, float fend, uint op ) {
    if ( color.a == 0.0 ) {
        return;
    }

    if ((op & FOGFADE) > 0u) {
        color = linear_fog_real(color, length(backProject(vec4(scaledCoord, depth, 1.0)).xyz), fstart, fend, vec4(fog.rgb, 0.0));
    } else {
        color = linear_fog_real(color, length(backProject(vec4(scaledCoord, depth, 1.0)).xyz), fstart, fend, fog);
    }

    color_layers[active_layers] = color;
    depth_layers[active_layers] = depth;
    op_layers[active_layers] = op;

    int jj = active_layers++;
    int ii = jj - 1;
    while ( jj > 0 && depth > depth_layers[index_layers[ii]] ) {
        int indexTemp = index_layers[ii];
        index_layers[ii] = index_layers[jj];
        index_layers[jj] = indexTemp;

        jj = ii--;
    }
}

vec3 blend( vec3 dst, vec4 src ) {
    return mix(dst.rgb, src.rgb, src.a);
    // return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

vec3 blendmult( vec3 dst, vec4 src) {
    return dst * mix(vec3(1.0), src.rgb, src.a);
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
#define atmDensity 0.5

#define anisotropicIntensity 0.0 //Higher numbers result in more anisotropic scattering

#define skyColor vec3(0.3, 0.53, 1.0) * (1.0 + anisotropicIntensity) //Make sure one of the conponents is never 0.0

#define smooth(x) x*x*(3.0-2.0*x)

// #define zenithDensity(x) atmDensity / pow(max((x - zenithOffset) / (1.0 - zenithOffset), 0.008), 0.75)
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

void main() {
    vec3 fragpos = backProject(vec4(scaledCoord, 1.0, 1.0)).xyz;
    fragpos = normalize(fragpos);
    fragpos.y = abs(fragpos.y * 0.5);
    fragpos = normalize(fragpos);

    vec4 calculatedFog = vec4(1.0);
    float fstart = underWater > 0.5 ? fogStart : 0.01 * fogEnd;
    float fend = 2.25 * fogEnd;

    vec3 color = getAtmosphericScattering(fragpos, sunDir, true) * pi;
    color = jodieReinhardTonemap(color);
    color = pow(color, vec3(2.2)); //Back to linear

    float sdu = dot(vec3(0.0, 1.0, 0.0), sunDir);
    if (underWater > 0.5) {
        calculatedFog.rgb = fogColor.rgb;
    }
    else if (sdu > 0.0) {
        calculatedFog = vec4(color, 1.0);
    } else {
        calculatedFog.rgb = mix(fogColor.rgb, color, clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0));
    }

    op_layers[0] = DEFAULT;
    // crumbling, beacon_beam, leash, entity_translucent_emissive(warden glow)
    depth_layers[0] = decodeDepth(texture( DiffuseDepthSampler, texCoord));
    vec4 color0 = vec4( texture( DiffuseSampler, texCoord).rgb, 1.0 );

    if (depth_layers[0] < 1.0 || underWater > 0.5) {
        color0 = linear_fog_real(color0, length(backProject(vec4(scaledCoord, depth_layers[0], 1.0)).xyz), fstart, fend, calculatedFog);
    }
    color_layers[0] = color0;
    active_layers = 1;

    try_insert( texture(CloudsSampler, texCoord), texture(CloudsDepthSampler, texCoord).r, calculatedFog, fstart, fend, FOGFADE);
    try_insert( texture(TranslucentSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, calculatedFog, fstart, fend, DEFAULT); 
    try_insert( texture(ParticlesWeatherSampler, texCoord), decodeDepth(texture(ParticlesWeatherDepthSampler, texCoord)), calculatedFog, fstart, fend, DEFAULT);

    // translucent_moving_block, lines, item_entity_translucent_cull
    try_insert( texture(ItemEntitySampler, texCoord), texture(ItemEntityDepthSampler, texCoord).r, calculatedFog, fstart, fend, DEFAULT);
    vec3 texelAccum = color_layers[index_layers[0]].rgb;
    for ( int ii = 1; ii < active_layers; ++ii ) {
        if ((op_layers[index_layers[ii]] & BLENDMULT) > 0u) {
            texelAccum = blendmult( texelAccum, color_layers[index_layers[ii]]);
        } else {
            texelAccum = blend( texelAccum, color_layers[index_layers[ii]]);
        }
    }

    fragColor = vec4( texelAccum.rgb, 1.0 );
}
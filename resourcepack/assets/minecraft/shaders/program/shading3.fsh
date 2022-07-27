#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D DiffuseTSampler;
uniform sampler2D EdgeSampler;
uniform sampler2D ShadingSampler;
uniform vec2 OutSize;
uniform float Time;

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in mat4 Proj;
in mat4 ProjInv;
in float near;
in float far;
in float raining;
in float underWater;

out vec4 fragColor;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define THRESH 0.5
#define FPRECISION 4000000.0
#define PROJNEAR 0.05
#define FUDGE 32.0

#define EMISS_MULT 1.5

#define TINT_WATER vec3(0.0 / 255.0, 248.0 / 255.0, 255.0 / 255.0)
#define WATER_COLOR_DEPTH 5.0

#define FLAG_UNDERWATER 1<<0
#define FLAG_RAINING    1<<1

#define PBRTYPE_STANDARD 0
#define PBRTYPE_EMISSIVE 1
#define PBRTYPE_SUBSURFACE 2
#define PBRTYPE_TRANSLUCENT 3
#define PBRTYPE_TEMISSIVE 4

#define FACETYPE_Y 0
#define FACETYPE_X 1
#define FACETYPE_Z 2
#define FACETYPE_S 3


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


// tweak lighting color here
#define NOON vec3(1.2, 1.15, 1.1)
#define NOONA vec3(0.5, 0.55, 0.75)
#define NOONM vec3(0.45, 0.5, 0.7)
#define EVENING vec3(1.35, 1.0, 0.5)
#define EVENINGA vec3(0.45, 0.5, 0.7)
#define EVENINGM vec3(0.35, 0.4, 0.65)
#define NIGHT vec3(0.7, 0.7, 0.7)
#define NIGHTA vec3(0.75, 0.8, 0.9)
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
#define atmDensity 0.4

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

vec4 decodeYUV(sampler2D tex, vec4 inCol, vec2 coord) {
    vec2 pixCoord = coord * OutSize;
    vec4 outCol = vec4(1.0);
    // vec2 dir = vec2(pixCoord.x <= 0.5 ? 1.0 : -1.0, pixCoord.y <= 0.5 ? 1.0 : 0.0);
    vec2 sec1 = texture(tex, coord + vec2(1.0, 0.0) * oneTexel).xy;
    vec2 sec2 = texture(tex, coord + vec2(-1.0, 0.0) * oneTexel).xy;
    float sec = sec1.y;
    if (abs(inCol.x - sec2.x) < abs(inCol.x - sec1.x)) {
        sec = sec2.y;
    }

    vec3 yuv = vec3(0.0);
    if (int(pixCoord.x) % 2 == 0) {
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
    // return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

#define BLENDMULT_FACTOR 0.5

vec3 blendmult( vec3 dst, vec4 src) {
    return BLENDMULT_FACTOR * dst * mix(vec3(1.0), src.rgb, src.a) + (1.0 - BLENDMULT_FACTOR) * mix(dst.rgb, src.rgb, src.a);
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

    vec4 outColor = texture(DiffuseSampler, texCoord);
    float depth = decodeDepth(texture(DiffuseDepthSampler, texCoord));
    vec2 data = outColor.ba;
    bool isSky = linearizeDepth(depth) >= far - FUDGE;
    outColor = decodeYUV(DiffuseSampler, outColor, texCoord);

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
            if (face == FACETYPE_S && stype == PBRTYPE_STANDARD) {
                applyLight = clamp(float(int(data.x * 255.0) / 16) / 15.0, 0.0, 1.0);
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
                ambient = mix(EVENINGA, NIGHTA, pow(-sdu, 0.5));
                backside = mix(EVENINGM, NIGHTM, pow(-sdu, 0.5));
            }

            // apply ambient occlusion.
            outColor.rgb *= vec3(texture(ShadingSampler, texCoord).b);

            // apply lighting color. not quite standard diffuse light equation since the blocks are already "pre-lit"
            vec3 shade = vec3(texture(ShadingSampler, texCoord).r);

            vec3 eyedir = normalize(fragpos);
            float comp_bp = max(pow(dot(reflect(sunDir, normal), eyedir), 8.0), 0.0);
            float comp_diff = dot(normal, sunDir);

            vec3 lightColor = ambient;

            if (face == FACETYPE_S && stype == PBRTYPE_SUBSURFACE) {
                float volume = texture(ShadingSampler, texCoord).g;
                float comp_sss = max(mix(pow(1.0 - volume, 2.0) - pow(length(scaledCoord), 4.0), comp_diff, 0.25), comp_diff);
                lightColor += (direct - ambient) * clamp((comp_bp * 0.25 + comp_sss + 0.05) * shade, 0.0, 1.0); 
            }
            else {
                lightColor += (direct - ambient) * clamp((comp_bp * 0.25 + comp_diff + 0.05) * shade, 0.0, 1.0); 
            }
            lightColor += (backside - ambient) * clamp(dot(normal, moonDir), 0.0, 1.0); 
            if (face == FACETYPE_S && stype == PBRTYPE_EMISSIVE) {
                outColor.rgb *= EMISS_MULT;
                lightColor = max(lightColor, vec3(EMISS_MULT));
            }

            outColor.rgb = mix(outColor.rgb * mix(lightColor, vec3(1.0), applyLight), lightColor, 0.0);//clamp(0.25 * (luma(lightColor) * (1.0 - applyLight) - 1.0), 0.0, 1.0));

            if (underWater > 0.5) {
                outColor.rgb = mix(outColor.rgb, outColor.rgb * TINT_WATER, smoothstep(0, WATER_COLOR_DEPTH * 6.0, length(fragpos)));
            }

            // desaturate bright pixels for more realistic feel
            outColor.rgb = mix(outColor.rgb, vec3(luma(outColor.rgb)), pow(luma(outColor.rgb), 2.0) * 0.5);

            // outColor.rgb = vec3(applyLight);

            // outColor.r = float(face == 0);
            // outColor.rgb = vec3(float(face) / 3.0);
            // if (face == 3) {
            //     outColor.rgb = vec3(clamp(float(int(data.x * 255.0) / 16) / 15.0, 0.0, 1.0));
            // } else {
            //     outColor.rgb = vec3(clamp(float(int(data.y * 255.0) / 4) / 63.0, 0.0, 1.0));
            // }
            // outColor.rgb = vec3(linearizeDepth(depth) / (far / 3.0));
            // outColor.rgb = 0.5 * (normal + vec3(1.0));
            // outColor.a = 1.0;
            // outColor.rgb = vec3(float(stype) / 8.0);
            // outColor.rgb = vec3(data.y);

            // vec4 yuva = vec4(0.0);

            // outColor.rgb = min(outColor.rgb, vec3(1.0));

            // if (gl_FragCoord.x > OutSize.x / 2.0) {
            //     yuva.x = outColor.r * 0.299 + outColor.g * 0.587 + outColor.b * 0.114;
            //     yuva.y = outColor.r * -0.169 + outColor.g * -0.331 + outColor.b * 0.5 + 0.5;
            //     yuva.z = outColor.r * 0.5 + outColor.g * -0.419 + outColor.b * -0.081 + 0.5;

            //     yuva = vec4(yuva.x, (yuva.y - 0.5), (yuva.z - 0.5), 1.0);

            //     outColor.r = yuva.x * 1.0 + yuva.y * 0.0 + yuva.z * 1.4;
            //     outColor.g = yuva.x * 1.0 + yuva.y * -0.343 + yuva.z * -0.711;
            //     outColor.b = yuva.x * 1.0 + yuva.y * 1.765 + yuva.z * 0.0;
            // }
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
                outColor = vec4(color, 1.0 );
            } else {
                outColor.rgb = mix(outColor.rgb, color, clamp(5.0 * (0.2 - pow(abs(sdu), 1.5)), 0.0, 1.0));
            }

        }

        vec4 translucent = texture(DiffuseTSampler, texCoord);
        if (translucent.a > 0.0) {
            if (int(translucent.a * 255.0) % 2 == 0) { // PBRTYPE_TRANSLUCENT
                outColor.rgb = blendmult(outColor.rgb, translucent);
            }
            else { // PBRTYPE_TEMISSIVE
                outColor.rgb += translucent.rgb * translucent.a * EMISS_MULT;
            }
        }
    }

    fragColor = outColor;
}

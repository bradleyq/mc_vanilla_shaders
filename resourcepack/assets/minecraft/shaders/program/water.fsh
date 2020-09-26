#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D TerrainCloudsSampler;

varying vec2 texCoord;
varying float aspectRatio;
varying float cosFOVrad;
varying vec3 normal;
varying mat4 gbPI;
varying mat4 gbP;

#define TAPS 32
#define SKYTAPS 64

#define near 0.0001
#define far 1.0
  
float LinearizeDepth(float depth) 
{
    return 2.0 * (near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));    
}

float ditherGradNoise() {
  return fract(52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y));
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

    vec4 color = texture2D(TranslucentSampler, texCoord);
    float wdepth = texture2D(TranslucentDepthSampler, texCoord).r;

    vec4 reflection = vec4(0.0);

    if (color.a > 0.01) {
        vec3 sky = vec3(0.0);
        float successes = 0.01;
        for (int i = SKYTAPS - 1; i > -1; i--) {
            vec2 ctmp = (poissonDisk[i] + vec2(1.0, 3.0)) * vec2(0.5, 0.25);
            float depth = texture2D(DiffuseDepthSampler, ctmp).r;
            if (depth >= 1.0) {
                successes += 1.0;
                sky += texture2D(DiffuseSampler, ctmp).rgb;
            }
        }

        sky /= successes;

        vec2 reflectApprox = vec2(0.0);
        
        float ndu = abs(dot(normal, vec3(0.0, 1.0, 0.0)));
        float horizon = clamp(dot(normal, vec3(0.0, 0.0, 1.0)) * 1000.0, -1.0, 1.0);
        reflectApprox = vec2(texCoord.x, 0.95 - texCoord.y + horizon * pow(clamp((1.0 - ndu) / (1.0 - cosFOVrad), 0.0, 1.0), 0.5) * 1.0);
        for (int i = 0; i < TAPS; i++) {
            vec2 ratmp = reflectApprox + poissonDisk[i] * vec2(1.0 / aspectRatio, 1.0) * 0.01;
            float tdepth = texture2D(DiffuseDepthSampler, ratmp).r;
            if (tdepth > wdepth) {
                reflection += texture2D(TerrainCloudsSampler, ratmp);
            }
        }
        reflection /= float(TAPS);
        if (reflectApprox.y > 1.0 && dot(sky, vec3(1.0)) > 0.0) {
            reflection.rgb = mix(reflection.rgb, sky, clamp((reflectApprox.y - 1.0) * 20.0, 0.0, 1.0));
        }

        float ldpeth = LinearizeDepth(wdepth);
        vec4 fragpos  = gbPI * vec4(texCoord, ldpeth, 1.0);
        fragpos *= ldpeth;

        const int samples       = 25;
        const int maxRefinement = 12;
        const float stepSize    = 0.0015;
        const float stepRefine  = 0.26;
        const float stepIncrease = 1.2;

        vec3 col        = vec3(0.0);
        vec3 rayStart   = fragpos.xyz;
        vec3 rayDir     = reflect(normalize(fragpos.xyz), vec3(normal.x, -normal.y, normal.z));
        vec3 rayStep    = (stepSize + stepSize * 0.1 * (ditherGradNoise()-0.5)) * rayDir;
        vec3 rayPos     = rayStart + rayStep;
        vec3 rayPrevPos = rayStart;
        vec3 rayRefine  = rayStep;

        int refine  = 0;
        vec3 pos    = vec3(0.0);
        float edge  = 0.0;

        for (int i = 0; i < samples; i++) {
            pos = (gbP * vec4(rayPos.xyz, 1.0)).xyz;
            pos.xy /= rayPos.z;
            if (pos.x < 0.0 || pos.x > 1.0 || pos.y < 0.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) break;
            float dist = LinearizeDepth(texture2D(DiffuseDepthSampler, pos.xy).r);
            dist = abs(rayPos.z - dist);

            if (dist < pow(length(rayStep)*pow(length(rayRefine), 0.11), 1.1)*4.5) {
                refine++;
                if (refine >= maxRefinement)	break;
                rayRefine  -= rayStep;
                rayStep    *= stepRefine;
            }

            rayStep        *= stepIncrease;
            rayPrevPos      = rayPos;
            rayRefine      += rayStep;
            rayPos          = rayStart+rayRefine;

        }
        vec3 candidate = mix(texture2D(TerrainCloudsSampler, pos.xy).rgb, sky, clamp(pos.z, 0.0, 1.0));
        reflection = mix(vec4(candidate, 1.0), reflection, clamp(pow(max(abs(pos.x - 0.5), abs(pos.y - 0.5)) * 2.0, 4.0), 0.0, 1.0));
        
        float fresnel = 1.0 - abs(dot(normalize(fragpos.xyz), vec3(normal.x, -normal.y, normal.z)));
        fresnel = clamp(exp((fresnel - 1.0) * (4.0 + clamp(exp(clamp(0.95 - ndu, 0.0, 1.0) * 6.0) - 1.0, 0.0, 1.0) * 25.0)), 0.0, 1.0);


        color = vec4(mix(color.rgb, reflection.rgb, clamp((length(reflection.rgb) * 0.5 + 0.5) * fresnel, 0.0, 1.0)), color.a);
        gl_FragColor = color;
    }

}

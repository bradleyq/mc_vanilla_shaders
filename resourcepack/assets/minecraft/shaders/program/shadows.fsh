#version 150

in vec2 texCoord;
in vec2 oneTexel;
in vec3 sunDir;
in mat4 projMat;
in mat4 modelViewMat;
in vec3 chunkOffset;
in vec3 rayDir;
in float near;
in float far;
in mat4 projInv;
in float underWater;
in float validControl;

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D DataSampler;
uniform sampler2D DataDepthSampler;

uniform vec2 OutSize;

out vec4 fragColor;

const ivec2 GRID_SIZE = ivec2(1024, 705);
const int AREA_SIDE_LENGTH = int(pow(float(GRID_SIZE.x * GRID_SIZE.y / 2), 1.0 / 3.0));

ivec2 positionToCell(vec3 position, out bool inside) {
    ivec3 sides = ivec3(AREA_SIDE_LENGTH);

    ivec3 iPosition = ivec3(floor(position));
    iPosition += sides / 2;

    inside = true;
    if (clamp(iPosition, ivec3(0), sides - 1) != iPosition) {
        inside = false;
        return ivec2(-1);
    }

    int index = (iPosition.y * sides.z + iPosition.z) * sides.x + iPosition.x;
    
    int halfWidth = GRID_SIZE.x / 2;
    ivec2 result = ivec2(
        (index % halfWidth) * 2,
        index / halfWidth + 1
    );
    result.x += result.y % 2;

    return result;
}

ivec2 cellToPixel(ivec2 cell, ivec2 screenSize) {
    return ivec2(round(vec2(cell) / GRID_SIZE * screenSize));
}

ivec2 positionToPixel(vec3 position, vec2 ScreenSize, out bool inside) {
    ivec2 cell = positionToCell(floor(position), inside);
    return cellToPixel(cell, ivec2(ScreenSize));
}

vec3 depthToView(vec2 texCoord, float depth, mat4 projInv) {
    vec4 ndc = vec4(texCoord, depth, 1.0) * 2.0 - 1.0;
    vec4 viewPos = projInv * ndc;
    return viewPos.xyz / viewPos.w;
}

vec3 safeDenom(vec3 v) {
    return vec3(v.r == 0.0 ? 0.001 : v.r, v.g == 0.0 ? 0.001 : v.g, v.b == 0.0 ? 0.001 : v.b);
}

#define S_PENUMBRA 0.02
#define S_SAMPLES 16
#define S_MAXREFINESAMPLES 1
#define S_STEPSIZE 0.1
#define S_STEPREFINE 0.4
#define S_STEPINCREASE 1.2
#define S_IGNORETHRESH 4.0

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

vec4 backProject(vec4 vec) {
    vec4 tmp = projInv * vec;
    return tmp / tmp.w;
}

float Shadow(vec3 fragpos, vec3 sundir, float fragdepth, float rand) {
    vec3 rayStart   = fragpos + abs(rand) * sundir * S_STEPSIZE;
    vec3 rayDir     = sundir;
    vec3 rayStep    = (S_STEPSIZE + S_STEPSIZE * 0.5 * (rand + 1.0)) * rayDir;
    vec3 rayPos     = rayStart + rayStep;
    vec3 rayPrevPos = rayStart;
    vec3 rayRefine  = rayStep;

    int refine  = 0;
    vec4 pos    = vec4(0.0);
    float edge  = 0.0;
    float dtmp  = 0.0;
    float dist  = 0.0;
    float distmult = 1.0;
    float strength = 0.0;

    for (int i = 0; i < S_SAMPLES; i += 1) {
        pos = projMat * vec4(rayPos.xyz, 1.0);
        pos.xyz /= pos.w;
        if (pos.x < -1.0 || pos.x > 1.0 || pos.y < -1.0 || pos.y > 1.0 || pos.z < 0.0 || pos.z > 1.0) return 1.0;
        dtmp = linearizeDepth(texture(DiffuseDepthSampler, 0.5 * pos.xy + vec2(0.5)).r);
        dist = (linearizeDepth(pos.z) - dtmp);

        if (dist < distmult * max(length(rayStep) * pow(length(rayRefine), 0.2) * (1.0 + 1.0 * clamp(pow(abs(dot(normalize(fragpos), sunDir)), 4.0), 0.0, 1.0)), 0.2) && dist > length(fragpos) / 512.0) {
            break;
        }

        if (dist > length(fragpos) / 512.0) {
            distmult *= 1.25;
        }
        else if (distmult > 1.2) {
            distmult /= 1.25;
        }

        rayStep        *= S_STEPINCREASE;
        rayPrevPos      = rayPos;
        rayRefine      += rayStep;
        rayPos          = rayStart+rayRefine;

        if (i == S_SAMPLES - 1.0) {
        return 1.0;
        }
        strength += 1.0 / S_SAMPLES;
    }

    if (dist < S_IGNORETHRESH && dtmp < far * 0.5) {
        return strength;
    }
    return 1.0;
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


    fragColor = vec4(1.0);

    if (texCoord.y <= 0.5 && validControl > 0.5) {
        vec2 scaledCoord = texCoord;
        scaledCoord.y = scaledCoord.y * 2.0 - oneTexel.y * 0.5;

        
        float depth = texture(DiffuseDepthSampler, scaledCoord).r;
        vec2 ndcCoord = 2.0 * (scaledCoord - vec2(0.5));
        vec3 fragpos = backProject(vec4(ndcCoord, depth, 1.0)).xyz;
        vec3 viewPos = depthToView(scaledCoord, depth, projInv) * 0.999;    
        float shadow = 1.0;
        float shadowdist = max(far / 4.0 - 48.0, 16.0) * (1.0 - underWater);
        float fragdist = length(viewPos);

        if (fragdist < shadowdist && scaledCoord.x > oneTexel.x && scaledCoord.y > oneTexel.y) {
            float depth1 = texture(DiffuseDepthSampler, scaledCoord - vec2(oneTexel.x, 0.0)).r;
            float depth2 = texture(DiffuseDepthSampler, scaledCoord - vec2(0.0, oneTexel.y)).r;
            vec2 ndcCoord1 = 2.0 * (scaledCoord - vec2(oneTexel.x, 0.0) - vec2(0.5));
            vec2 ndcCoord2 = 2.0 * (scaledCoord - vec2(0.0, oneTexel.y) - vec2(0.5));
            vec3 fragpos1 = backProject(vec4(ndcCoord1, depth1, 1.0)).xyz;
            vec3 fragpos2 = backProject(vec4(ndcCoord2, depth2, 1.0)).xyz;

            vec3 normal = normalize(cross(fragpos1 - fragpos, fragpos2 - fragpos));
            shadow = smoothstep(-0.2, 0.05, dot(normal,sunDir));
        }



        vec3 blockPos = ceil(viewPos - fract(chunkOffset));

        bool inside;
        vec3 start = viewPos - fract(chunkOffset);
        float travel = 0.0; 
        vec3 c1 = normalize(cross(sunDir, vec3(0.0, 1.0, 0.0)));
        vec3 c2 = normalize(cross(c1, sunDir));
        int index = (int(gl_FragCoord.x) * 704657 + int(gl_FragCoord.y) * 8221427 + 13) % 71867 % 64;
        vec3 tracedir = normalize(sunDir + S_PENUMBRA * (c1 * poissonDisk[index].x + c2 * poissonDisk[index].y));
        if (fragdist < 48.0) {
            for (int i = 0; i < 48; i++) {
                vec3 current = start + tracedir * (travel + 0.04 * fragdist / 20.0);

                ivec2 pix = positionToPixel(floor(current), OutSize, inside);

                vec3 signs = sign(tracedir);
                current -= floor(current);
                current = vec3(signs.r > 0.0 ? 1.0 - current.r : current.r, signs.g > 0.0 ? 1.0 - current.g : current.g, signs.b > 0.0 ? 1.0 - current.b : current.b);
                vec3 times = current / safeDenom(abs(tracedir));
                travel = travel + (0.04 * fragdist / 20.0) + min(min(times.x, times.y), times.z);

                if (inside && texelFetch(DataDepthSampler, pix, 0).r < 0.001) {
                    shadow = min(shadow, clamp(pow(float(travel) / 32.0, 2.0) + smoothstep(32.0 - underWater * 16.0, 38.0, fragdist), 0.0, 1.0));
                    break;
                }
                
            }   
        }

        if (fragdist < shadowdist) {
            int k = int((fragpos.x + fragpos.y + fragpos.z) * 874.0) % 60;
            float tmps = Shadow(fragpos, normalize(sunDir + S_PENUMBRA * vec3(poissonDisk[k].x, 0.0, poissonDisk[k].y)), linearizeDepth(depth), poissonDisk[k+1].x);
            tmps = pow(tmps, 4);
            shadow = min(shadow, tmps);
        }

        shadow = min(shadow + smoothstep(shadowdist - 16.0, shadowdist, fragdist), 1.0);
        shadow = shadow * 0.5 + 0.5;

        fragColor.rgb *= max(min(shadow + 0.3 * underWater, 1.0), 0.5 + 0.5 * clamp(1.0 - dot(sunDir, vec3(0.0, 1.0, 0.0)), 0.0, 1.0));
    }
}
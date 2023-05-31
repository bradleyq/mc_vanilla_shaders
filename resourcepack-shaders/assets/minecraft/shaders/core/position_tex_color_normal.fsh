#version 330
#define FSH

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;
uniform vec4 FogColor;

in vec2 texCoord0;
in float vertexDistance;
in vec4 vertexColor;
in vec3 normal;
in vec3 gpos;
in float yval;

out vec4 fragColor;

#define CLOUD_W 12.0
#define CLOUD_H 8.0
#define ABSORPTION 0.1
#define SCATTER 0.1
#define ATTENUATION (ABSORPTION + SCATTER)
#define MAX_VOXELS 4
#define FUDGE 0.000001
#define WRAP_RADIUS (CLOUD_W * 0.1)
#define WRAP_AMOUNT 0.1

bool inCloud(vec3 pos) {
    return pos.x >= 0.0 && pos.y >= 0.0 && pos.z >= 0.0 && pos.x <= CLOUD_W &&  pos.y <= CLOUD_H &&  pos.z <= CLOUD_W;
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

void main() {
    vec4 color = texture(Sampler0, texCoord0);

    if (color.a > 0.1) {
        vec2 oneTexel = 1.0 / vec2(textureSize(Sampler0, 0));

        vec3 dir = normalize(gpos);
        vec3 lpos = vec3(0.0, yval * CLOUD_H, 0.0);
        vec2 luv = mod(texCoord0 * vec2(textureSize(Sampler0, 0)), 1.0) * CLOUD_W;
        float dist = 0.0;
        float distatt = 0.0;
        float hs = (1.0 - yval) * CLOUD_H;
        float he = 0.0;
        bool trace = true;
        bool incloud = false;



        if (dir.x == 0.0) {
            dir.x += FUDGE;
        }
        if (dir.y == 0.0) {
            dir.y += FUDGE;
        }
        if (dir.z == 0.0) {
            dir.z += FUDGE;
        }

        float signx = -1.0 + 2.0 * float(dir.x > 0.0);
        float signy = -1.0 + 2.0 * float(dir.y > 0.0);
        float signz = -1.0 + 2.0 * float(dir.z > 0.0);

        if (dot(normal, vec3(1.0, 0.0, 0.0)) > 0.99) {
            lpos.xz = vec2(CLOUD_W, luv.y);
            if (dir.x > 0.0) {
                dist = length(gpos);
                hs = hs + gpos.y;
            }
        }
        else if (dot(normal, vec3(1.0, 0.0, 0.0)) < -0.99) {
            lpos.xz = vec2(0.0, luv.y);
            if (dir.x < 0.0) {
                dist = length(gpos);
                hs = hs + gpos.y;
            }
        }
        else if (dot(normal, vec3(0.0, 0.0, 1.0)) > 0.99) {
            lpos.xz = vec2(luv.x, CLOUD_W);
            if (dir.z > 0.0) {
                dist = length(gpos);
                hs = hs + gpos.y;
            }
        }
        else if (dot(normal, vec3(0.0, 0.0, 1.0)) < -0.99) {
            lpos.xz = vec2(luv.x, 0.0);
            if (dir.z < 0.0) {
                dist = length(gpos);
                hs = hs + gpos.y;
            }
        }
        else {
            lpos.xz = vec2(luv.x, luv.y);
            if ((dot(normal, vec3(0.0, 1.0, 0.0)) > 0.99 && dir.y > 0.0)
             || (dot(normal, vec3(0.0, 1.0, 0.0)) < -0.99 && dir.y < 0.0)) {
                dist = length(gpos);
                he = hs;
                hs = hs + gpos.y;
                trace = false;
            }
        }

        incloud = inCloud(lpos - (gpos));
        if (dist > 0.0 && !incloud) {
            discard;
        }

        distatt = dist;
        float edgedist = 0.0;

        if (dot(normal, vec3(0.0, 1.0, 0.0)) < -0.99) {
            float edgedistx = CLOUD_W * 0.5;
            float edgedistz = CLOUD_W * 0.5;

            if (CLOUD_W - lpos.x < edgedistx && texture(Sampler0, texCoord0 + vec2(oneTexel.x, 0.0)).a < 0.1) {
                edgedistx = CLOUD_W - lpos.x;
            }
            else if (lpos.x < edgedistx && texture(Sampler0, texCoord0 + vec2(-oneTexel.x, 0.0)).a < 0.1) {
                edgedistx = lpos.x;
            }

            if (CLOUD_W - lpos.z < edgedistz && texture(Sampler0, texCoord0 + vec2(0.0, oneTexel.y)).a < 0.1) {
                edgedistz = CLOUD_W - lpos.z;
            }
            else if (lpos.z < edgedistz && texture(Sampler0, texCoord0 + vec2(0.0, -oneTexel.y)).a < 0.1) {
                edgedistz = lpos.z;
            }
            if (edgedistx < WRAP_RADIUS && edgedistz < WRAP_RADIUS) {
                // edgedist = max(CLOUD_W * 0.5 - length(lpos.xz - vec2(CLOUD_W * 0.5)), 0.0);
                edgedist = max(WRAP_RADIUS - length(vec2(edgedistx, edgedistz) - vec2(WRAP_RADIUS)), 0.0);
            }
            else {
                edgedist = min(edgedistx, edgedistz);
            }

            if (length(lpos.xz) < edgedist && texture(Sampler0, texCoord0 + vec2(-oneTexel.x, -oneTexel.y)).a < 0.1) {
                edgedist = length(lpos.xz);
            }
            else if (length(vec2(lpos.x, CLOUD_W - lpos.z)) < edgedist && texture(Sampler0, texCoord0 + vec2(-oneTexel.x, oneTexel.y)).a < 0.1) {
                edgedist = length(vec2(lpos.x, CLOUD_W - lpos.z));
            }
            else if (length(vec2(CLOUD_W - lpos.x, lpos.z)) < edgedist && texture(Sampler0, texCoord0 + vec2(oneTexel.x, -oneTexel.y)).a < 0.1) {
                edgedist = length(vec2(CLOUD_W - lpos.x, lpos.z));
            }
            else if (length(vec2(CLOUD_W - lpos.x, CLOUD_W - lpos.z)) < edgedist && texture(Sampler0, texCoord0 + vec2(oneTexel.x, oneTexel.y)).a < 0.1) {
                edgedist = length(vec2(CLOUD_W - lpos.x, CLOUD_W - lpos.z));
            }
        }

        if (trace) {

            vec2 traceCoord = texCoord0;

            bool bail = false;
            bool air = false;
            for (int i = 0; i < MAX_VOXELS; i += 1) {
                vec2 offset = vec2(0.0);
                float tmin = 1.0 / FUDGE;

                float temp;
                temp = dir.x > 0 ? (CLOUD_W - lpos.x) / dir.x : -lpos.x / dir.x;
                if (temp < tmin) {
                    tmin = temp;
                    offset = signx * vec2(oneTexel.x, 0.0);
                }

                temp = dir.z > 0 ? (CLOUD_W - lpos.z) / dir.z : -lpos.z / dir.z;
                if (temp < tmin) {
                    tmin = temp;
                    offset = signz * vec2(0.0, oneTexel.y);
                }

                temp = dir.y > 0 ? (CLOUD_H - lpos.y) / dir.y : -lpos.y / dir.y;
                if (temp < tmin) {
                    tmin = temp;
                }

                if (!bail) {
                    dist += tmin;
                }
                if (!air) {
                    distatt += tmin;
                }

                traceCoord += offset;
                traceCoord = mod(traceCoord, 1.0);
                if (offset.x == 0.0) {
                    lpos.xy += tmin * dir.xy;
                    lpos.z = offset.y > 0.0 ? 0.0 : CLOUD_W;
                    if (!bail) {
                        he = CLOUD_H - lpos.y;
                    }
                }
                else if (offset.y == 0.0) {
                    lpos.x = offset.x > 0.0 ? 0.0 : CLOUD_W;
                    lpos.yz += tmin * dir.yz;
                    if (!bail) {
                        he = CLOUD_H - lpos.y;
                    }
                }
                else {
                    break;
                }

                color = texture(Sampler0, traceCoord);
                if (color.a < 0.1) {
                    air = true;
                    bail = true;
                }
                else {
                    air = false;
                }
            }
        }

        float hd = he - hs;
        float ld = sqrt(hd * hd + dist * dist);
        float m = hd / ld;
        float scatter = SCATTER / (-ATTENUATION * (m + 1)) * (exp(-ATTENUATION * ((m + 1) * dist + hs)) - exp(-ATTENUATION * hs));
        if (!incloud) {
            scatter = (1.0 - WRAP_AMOUNT) * yval + WRAP_AMOUNT * smoothstep(WRAP_RADIUS, 0.0, edgedist);
        }
        int seed = int(gl_FragCoord.x) + int(gl_FragCoord.y) * 853;
        vec4 noise = 2 * vec4(vec3(PRNG(seed)) - 0.5, PRNG(seed + 1) - 0.5) / 255.0;

        fragColor = vec4(vec3(scatter), 1.0 - exp(-ATTENUATION * distatt)) + noise;
    }
    else {
        discard;
    }
}

#version 150

uniform sampler2D DiffuseSampler;
uniform float Tolerance;
uniform float Reject;

in vec2 texCoord;
in vec2 oneTexel;

out vec4 fragColor;

int intmod(int i, int base) {
    return i - (i / base * base);
}

vec3 encodeInt(int i) {
    int r = intmod(i, 255);
    i = i / 255;
    int g = intmod(i, 255);
    i = i / 255;
    int b = intmod(i, 255);
    return vec3(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0);
}

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int num = 0;
    num += int(ivec.r);
    num += int(ivec.g) * 255;
    num += int(ivec.b) * 255 * 255;
    return num;
}

void main() {
    vec4 outColor = vec4(0.0);
    if (texCoord.x < 0.25 && texCoord.y < 0.25) {
        vec2 scaledCoord = texCoord * 2.0 - 0.5 * oneTexel;
        vec4 sampleColor = texture(DiffuseSampler, scaledCoord);
        if (sampleColor.a > 0.0) {
            float avg = 0.0;
            float count = 0.0;
            float tmp;
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(1.0, 0.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(1.0, 1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(0.0, 1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(-1.0, 1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(-1.0, 0.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(-1.0, -1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(0.0, -1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            tmp = float(decodeInt(texture(DiffuseSampler, scaledCoord + vec2(1.0, -1.0) * oneTexel).rgb));
            avg += tmp;
            count += float(tmp > 0.0);
            if (count > Reject) {
                avg /= count;
                float centerVal = float(decodeInt(sampleColor.rgb));
                if (abs(avg - centerVal) < Tolerance) {
                    outColor = vec4(encodeInt(int(floor((count * avg + centerVal) / (count + 1) + 0.5))), sampleColor.a);
                }
            }
        }
    }
    

    fragColor = outColor;
}

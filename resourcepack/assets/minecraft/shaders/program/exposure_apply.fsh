#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D TemporalSampler;

varying vec2 texCoord;

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

#define EXPOSURE_PRECISION 1000000

void main() {
    vec4 OutTexel = texture2D(DiffuseSampler, texCoord);
    float exposure = decodeInt(texture2D(TemporalSampler, vec2(10.5 / 16.0, 0.5)).rgb) / float(EXPOSURE_PRECISION);

    OutTexel.rgb /= 2.0 * clamp(exposure,0.2,1.0);
    OutTexel.rgb = mix(OutTexel.rgb, vec3((OutTexel.r + OutTexel.g + OutTexel.b) / 3.0), clamp(length(OutTexel.rgb) - 0.73205080757, 0.0, 1.0));

    gl_FragColor = OutTexel;
}

#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

vec3 blend( vec3 dst, vec4 src ) {
    return mix(dst.rgb, src.rgb, src.a);
}

vec3 blendadd( vec3 dst, vec4 src ) {
    return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

#define BLENDMULT_FACTOR 0.5

vec3 blendmult( vec3 dst, vec4 src) {
    return BLENDMULT_FACTOR * dst * mix(vec3(1.0), src.rgb, src.a) + (1.0 - BLENDMULT_FACTOR) * mix(dst.rgb, src.rgb, src.a);
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

void main() {
    vec4 c0 = decodeHDR_1(texture(DiffuseSampler, texCoord));
    float d0 = texture(DiffuseDepthSampler, texCoord).r;

    vec4 c1 = texture(WeatherSampler, texCoord); 
    float d1 = texture(WeatherDepthSampler, texCoord).r;

    if (d1 < d0) {
        vec4 tmp0 = c0;
        c0 = c1;
        c1 = tmp0;
    }

    c0 = vec4(blendadd(c1.rgb, c0), c0.a + (1.0 - c0.a) * c1.a);
    fragColor = encodeHDR_1(c0);
}
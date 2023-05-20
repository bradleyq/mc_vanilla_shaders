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

void main() {
    vec4 c0 = texture(DiffuseSampler, texCoord);
    float d0 = texture(DiffuseDepthSampler, texCoord).r;

    vec4 c1 = texture(WeatherSampler, texCoord); 
    float d1 = texture(WeatherDepthSampler, texCoord).r;

    if (d1 < d0) {
        vec4 tmp0 = c0;
        c0 = c1;
        c1 = tmp0;
    }

    c0 = vec4(blendadd(c1.rgb, c0), c0.a + (1.0 - c0.a) * c1.a);
    fragColor = c0;
}
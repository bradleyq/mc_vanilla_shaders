#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

void main() {
    vec4 c0 = texture(DiffuseSampler, texCoord);
    float d0 = texture(DiffuseDepthSampler, texCoord).r;

    vec4 c1 = texture(WeatherSampler, texCoord); 
    float d1 = texture(WeatherDepthSampler, texCoord).r;

    if (d1 < d0) {
        vec4 tmp0 = c0;
        float tmp1 = d0;
        c0 = c1;
        d0 = d1;
        c1 = tmp0;
        d1 = tmp1;
    }

    c0 = vec4(mix(c1.rgb, c0.rgb, c0.a), c0.a + (1.0 - c0.a) * c1.a);
    fragColor = c0;
    gl_FragDepth = d0;
}
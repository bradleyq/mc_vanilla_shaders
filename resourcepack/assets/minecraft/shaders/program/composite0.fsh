#version 120

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

varying vec2 texCoord;

void main() {
    float d0 = texture2D(DiffuseDepthSampler, texCoord).r;
    float d1 = texture2D(CloudsDepthSampler, texCoord).r;

    vec4 color = texture2D(DiffuseSampler, texCoord);
    if (d1 < d0) {
        vec4 colortmp = texture2D(CloudsSampler, texCoord);
        color.rgb = mix(color.rgb, colortmp.rgb, colortmp.a);
    }

    gl_FragColor = vec4(color.rgb, 1.0);
}

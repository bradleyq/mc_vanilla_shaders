#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;
out vec4 fragColor;

#define CLOUD_MULT vec4(1.25, 1.25, 1.25, 0.75)

void main() {
    float d0 = texture(DiffuseDepthSampler, texCoord).r;
    float d1 = texture(CloudsDepthSampler, texCoord).r;

    vec4 color = texture(DiffuseSampler, texCoord);
    if (d1 < d0) {
        vec4 colortmp = clamp(texture(CloudsSampler, texCoord) * CLOUD_MULT, vec4(0.0), vec4(1.0));
        // color.rgb = mix(color.rgb, colortmp.rgb, colortmp.a);
        color.rgb = 0.75 * mix(color.rgb, colortmp.rgb, colortmp.a) +  0.25 * color.rgb * mix(vec3(1.0), colortmp.rgb / clamp(max(colortmp.r, max(colortmp.g, colortmp.b)), 0.3, 1.0), clamp(colortmp.a, 0.0, 1.0));
    }

    fragColor = vec4(color.rgb, 1.0);
}

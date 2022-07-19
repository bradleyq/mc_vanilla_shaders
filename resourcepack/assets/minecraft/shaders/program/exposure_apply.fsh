#version 150

uniform sampler2D DiffuseSampler;

in vec2 texCoord;
in float exposure;

out vec4 fragColor;

void main() {
    vec4 OutTexel = texture(DiffuseSampler, texCoord);

    OutTexel.rgb /= 2.5 * clamp(exposure,0.3, 1.0);
    OutTexel.rgb = mix(OutTexel.rgb, vec3((OutTexel.r + OutTexel.g + OutTexel.b) / 3.0), clamp(length(OutTexel.rgb) - 0.73205080757, 0.0, 1.0));

    fragColor = OutTexel;
}

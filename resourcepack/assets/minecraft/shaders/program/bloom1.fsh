#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D BloomSampler;
uniform vec2 InSize;

in vec2 texCoord;
in vec2 oneTexel;
in float aspectRatio;

out vec4 fragColor;

void main() {

    vec3 OutTexel = texture(DiffuseSampler, texCoord).rgb;
    vec3 bloomAccumulator = texture(BloomSampler, texCoord).rgb;
    bloomAccumulator += texture(BloomSampler, texCoord + vec2(oneTexel.x, 0.0)).rgb;
    bloomAccumulator += texture(BloomSampler, texCoord - vec2(oneTexel.x, 0.0)).rgb;
    bloomAccumulator += texture(BloomSampler, texCoord + vec2(0.0, oneTexel.y)).rgb;
    bloomAccumulator += texture(BloomSampler, texCoord - vec2(0.0, oneTexel.y)).rgb;

    bloomAccumulator /= float(5);
    fragColor = vec4(OutTexel + bloomAccumulator, 1.0);
}

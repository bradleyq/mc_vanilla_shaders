#version 150

uniform sampler2D DiffuseSampler;
uniform vec2 BlurDir;
uniform float BlurSize;

in vec2 texCoord;
in vec2 oneTexel;
in float aspectRatio;

out vec4 fragColor;

void main() {
    vec4 outColor = texture(DiffuseSampler, texCoord);
    if (outColor.a > 0.0) {
        outColor = vec4(0.0);
        vec2 direction = normalize(BlurDir / vec2(aspectRatio, 1.0));
        float radius = BlurSize / oneTexel.y;
        float totalStrength = 0.0;

        for(float r = -radius; r <= radius; r += 1.0) {
            vec4 tmpColor = texture(DiffuseSampler, texCoord + oneTexel * r * direction);
            if (tmpColor.a > 0.0) {
                float strength = 1.0 - abs(r / radius);
                totalStrength += strength;
                outColor += tmpColor * strength;
            }
        }
        outColor /= totalStrength;
    }

    fragColor = outColor;
}

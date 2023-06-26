#version 330

uniform sampler2D DiffuseSampler;
uniform sampler2D TerrianDepthSampler;
uniform sampler2D TranslucentDepthSampler;

in vec2 texCoord;
in vec2 oneTexel;
in float near;
in float far;
in float underWater;
in float rain;

out vec4 fragColor;

#define WATER_COLOR_DEPTH 3.0
#define WATER_COLOR_BASE 0.25

float linearizeDepth(float depth) {
    return (2.0 * near * far) / (far + near - depth * (far - near));    
}

void main() {
    vec4 outColor = texture(DiffuseSampler, texCoord);

    if (int(outColor.a * 255.0) % 2 == 0) {
        if (underWater < 0.5) {
            outColor.a *= clamp(smoothstep(0.0, WATER_COLOR_DEPTH, linearizeDepth(texture(TerrianDepthSampler, texCoord).r) - linearizeDepth(texture(TranslucentDepthSampler, texCoord).r)), WATER_COLOR_BASE, 1.0);
            outColor.a = float(int(round(outColor.a * 127.0)) * 2) / 255.0;
        }
    }

    fragColor = outColor;
}

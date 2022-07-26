#version 330
#define FSH

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in float isWater;
in vec4 vertexColor;
in vec2 texCoord0;

out vec4 fragColor;

void main() {
    vec4 outColor = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (isWater > 0.5) {
        outColor.a = float(int(outColor.a * 255.0) / 2 * 2) / 255.0; 
    } else {
        outColor.a = pow(outColor.a, 0.5);
        outColor.a = float(int(outColor.a * 255.0) / 2 * 2 + 1) / 255.0; 
    }

    fragColor = outColor;
}

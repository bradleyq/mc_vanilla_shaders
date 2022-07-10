#version 330

#moj_import <fog.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in float isWater;
in vec4 vertexColor;
in vec2 texCoord0;

out vec4 fragColor;

void main() {
    fragColor = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (isWater > 0.5) {
        fragColor.a = float(int(fragColor.a * 255.0) / 2 * 2) / 255.0; 
    } else {
        fragColor.a = float(int(fragColor.a * 255.0) / 2 * 2 + 1) / 255.0; 
    }
}

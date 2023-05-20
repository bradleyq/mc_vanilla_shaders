#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec2 texCoord0;
in vec4 baseColor;
in vec4 vertexColor;
in float isBlock;

out vec4 fragColor;

#define BLOCK_ALPHA 0.75

void main() {
    vec4 color = textureLod(Sampler0, texCoord0, -4) * baseColor * vertexColor * ColorModulator;

    if (color.a < ALPHACUTOFF) {
        discard;
    }
    if (isBlock > 0.0001) {
        color.a = BLOCK_ALPHA;
    }
    
    fragColor = color;
}

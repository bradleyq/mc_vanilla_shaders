#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec2 texCoord0;
in vec2 texCoord2;
in vec4 baseColor;
in vec4 vertexColor;
in float isBlock;

out vec4 fragColor;

#define MIN_BLOCK_ALPHA 0.75

void main() {
    vec4 color = textureLod(Sampler0, texCoord0, -4);

    color *= baseColor * ColorModulator;

    if (color.a < ALPHACUTOFF) {
        discard;
    }

    int pbr = PBRTYPE_EMISSIVE;
    if (isBlock > 0.0001) {
        pbr = PBRTYPE_STANDARD;
        color.a = max(color.a, MIN_BLOCK_ALPHA);
    }

    color = getOutColorPtclRGBLock(color, vertexColor, texCoord2, pbr);
    
    fragColor = color;
}

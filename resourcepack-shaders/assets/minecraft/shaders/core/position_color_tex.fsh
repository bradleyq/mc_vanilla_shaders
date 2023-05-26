#version 330
#define FSH

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec2 texCoord0;

out vec4 fragColor;

void main() {
    vec4 color = texture(Sampler0, texCoord0) * vertexColor;
    if (color.a < 0.1) {
        discard;
    }
    color.a = 1.0 - (1.0 - color.a) * 0.5;
    fragColor = color * ColorModulator;
}

#version 150

#moj_import <fog.glsl>

uniform vec4 ColorModulator;

in vec4 vertexColor;

out vec4 fragColor;

void main() {
    vec4 color = vertexColor * ColorModulator;
    fragColor = color;
}

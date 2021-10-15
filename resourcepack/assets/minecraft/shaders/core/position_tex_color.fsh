#version 150

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform vec2 ScreenSize;

in vec2 texCoord0;
in vec4 vertexColor;

out vec4 fragColor;

void main() {
    int index = inControl(gl_FragCoord.xy, ScreenSize.x);
    if (index != -1) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec4 color = texture(Sampler0, texCoord0) * vertexColor;
        if (color.a < 0.1) {
            discard;
        }
        fragColor = color * ColorModulator;
    }
}

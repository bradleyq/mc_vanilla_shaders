#version 150

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

uniform mat4 ProjMat;
uniform vec4 ColorModulator;
uniform vec2 ScreenSize;

in vec2 texCoord0;
in vec4 vertexColor;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    if (!gui) {
        discardControl(gl_FragCoord.xy, ScreenSize.x);
    }

    vec4 color = texture(Sampler0, texCoord0) * vertexColor;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = color * ColorModulator;
}

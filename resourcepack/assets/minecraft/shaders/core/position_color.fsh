#version 150

#moj_import <utils.glsl>

in vec4 vertexColor;
in float isHorizon;

uniform vec4 ColorModulator;
uniform vec2 ScreenSize;

out vec4 fragColor;

void main() {
    if (isHorizon > 0.5) {
        discardControl(gl_FragCoord.xy, ScreenSize.x);
    }
    
    vec4 color = vertexColor;
    if (color.a == 0.0) {
        discard;
    }
    fragColor = color * ColorModulator;
}

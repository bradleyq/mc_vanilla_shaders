#version 330
#define FSH

#moj_import <utils.glsl>

in vec4 vertexColor;

uniform vec4 ColorModulator;
uniform vec2 ScreenSize;
uniform mat4 ProjMat;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    if (!gui) {
        discardControl(gl_FragCoord.xy, ScreenSize.x);
    }
    
    vec4 color = vertexColor * ColorModulator;

    if (color.a == 0.0) {
        discard;
    }

    if (!gui) {
        color = getOutColorSTDALock(color, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
    }
    
    fragColor = color;
}

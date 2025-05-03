#version 330
#define FSH

#moj_import <utils.glsl>

uniform sampler2D Sampler0;

in vec4 vertexColor;
in vec2 texCoord0;
in vec4 glpos;

out vec4 fragColor;

void main() {
    discardControlGLPos(gl_FragCoord.xy, glpos);

    vec4 color = texture(Sampler0, texCoord0);
    if (color.a < vertexColor.a) {
        discard;
    }
    fragColor = color;
}

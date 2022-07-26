#version 330
#define VSH

#moj_import <light.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;
in ivec2 UV2;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec4 ColorModulator;

out vec2 texCoord2;
flat out vec4 vertexColor;
out vec4 glpos;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vertexColor = Color * ColorModulator * texelFetch(Sampler2, UV2 / 16, 0);
    texCoord2 = UV2 / 255.0;
    texCoord2.x *= 1.0 - getSun(Sampler2);
    glpos = gl_Position;
}

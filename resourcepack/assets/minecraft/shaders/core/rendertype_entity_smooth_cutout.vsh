#version 330
#define VSH

#moj_import <light.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;

uniform sampler2D Sampler1;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec4 vertexColor;
out vec4 overlayColor;
out vec2 texCoord0;
out vec4 glpos;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    vertexColor = Color;
    overlayColor = texelFetch(Sampler1, UV1, 0);
    texCoord0 = UV0;
    glpos = gl_Position;
}

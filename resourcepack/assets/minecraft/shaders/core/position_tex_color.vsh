#version 330
#define VSH

in vec3 Position;
in vec2 UV0;
in vec4 Color;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;

out vec2 texCoord0;
out vec4 vertexColor;
out mat4 modelMat;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    texCoord0 = UV0;
    vertexColor = Color;
    modelMat = mat4(inverse(IViewRotMat)) * ModelViewMat;
}

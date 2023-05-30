#version 330
#define VSH

#moj_import <fog.glsl>

in vec3 Position;
in vec2 UV0;
in vec4 Color;
in vec3 Normal;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;
uniform int FogShape;

out vec2 texCoord0;
out float vertexDistance;
out vec4 vertexColor;
out vec3 normal;
out vec3 gpos;
out float yval;

void main() {

    texCoord0 = UV0;
    vertexDistance = fog_distance(ModelViewMat, Position, FogShape);

    vertexColor = Color;
    normal = Normal;
    gpos = IViewRotMat * (ModelViewMat * vec4(Position, 1.0)).xyz;

    yval = 0.0;

    int faceVert = gl_VertexID % 4;
    if (((faceVert == 1 || faceVert == 2) && abs(dot(normal, vec3(1.0, 0.0, 0.0))) > 0.99)
     || ((faceVert == 0 || faceVert == 1) && abs(dot(normal, vec3(0.0, 0.0, 1.0))) > 0.99)
     || (dot(normal, vec3(0.0, 1.0, 0.0)) > 0.99)){
        yval = 1.0;
    }
    else {
        gpos.y -= 4.0;
    }

    gl_Position = ProjMat * vec4(gpos * IViewRotMat, 1.0);
}

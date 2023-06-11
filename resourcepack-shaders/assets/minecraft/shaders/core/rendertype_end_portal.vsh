#version 330
#define VSH

#moj_import <projection.glsl>

in vec3 Position;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;

out vec4 glpos;
out vec3 pos;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    glpos = gl_Position;
    vec4 origin = inverse(ProjMat * ModelViewMat) * vec4(0.0, 0.0, -1.0, 1.0);
    origin.xyz /= origin.w;
    pos = IViewRotMat * (Position - origin.xyz);
}

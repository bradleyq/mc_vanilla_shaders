#version 330
#define VSH

#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;

out vec4 vertexColor;

#define HORIZON_DISTANCE 120.0
#define FUDGE 20.0

void main() {
    bool gui = isGUI(ProjMat);

    if (!gui && length((IViewRotMat * Position).xz) > HORIZON_DISTANCE - FUDGE) {
        gl_Position = VSH_DISCARD;
    }
    else {
        gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
    }
    
    vertexColor = Color;
}

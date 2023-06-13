#version 330
#define VSH

#moj_import <utils.glsl>

in vec3 Position;
in vec2 UV0;
in vec4 Color;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform mat3 IViewRotMat;
uniform float FogStart;
uniform float FogEnd;

out vec2 texCoord0;
out vec4 vertexColor;
out mat4 modelMat;
out vec3 pos;

void main() {
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);
    
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);
    pos = vec3(0.0);
    if (!gui && !hand) {
        gl_Position.z = -1.0 * gl_Position.w;

        vec4 origin = inverse(ProjMat * ModelViewMat) * vec4(0.0, 0.0, -1.0, 1.0);
        origin.xyz /= origin.w;
        pos = IViewRotMat * (Position - origin.xyz);
    }

    texCoord0 = UV0;
    vertexColor = Color;
    modelMat = mat4(inverse(IViewRotMat)) * ModelViewMat;
}

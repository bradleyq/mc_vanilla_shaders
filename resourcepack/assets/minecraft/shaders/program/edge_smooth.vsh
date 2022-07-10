#version 330

in vec4 Position;

uniform mat4 ProjMat;
uniform vec2 OutSize;

out vec2 texCoord;
flat out vec2 oneTexel;

void main() {
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    texCoord = Position.xy / OutSize;
    oneTexel = 1.0 / OutSize;

    gl_Position = vec4(outPos.xy, 0.2, 1.0);
}

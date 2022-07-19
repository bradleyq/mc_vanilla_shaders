#version 150

in vec4 Position;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform sampler2D DataSampler;

out vec2 texCoord;
out vec2 oneTexel;
out float fov;

#define PROJNEAR 0.05
#define FOV_FIXEDPOINT 100.0

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int num = 0;
    num += int(ivec.r);
    num += int(ivec.g) * 255;
    num += int(ivec.b) * 255 * 255;
    return num;
}

void main() {
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = Position.xy / OutSize;
    oneTexel = 1.0 / OutSize;
    fov = float(decodeInt(texture(DataSampler, vec2(0.5 / 16.0, 0.5)).rgb)) / FOV_FIXEDPOINT;
}

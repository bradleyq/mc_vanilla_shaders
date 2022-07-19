#version 150

in vec4 Position;

uniform sampler2D TemporalSampler;
uniform mat4 ProjMat;
uniform vec2 InSize;

out vec2 texCoord;
out vec2 oneTexel;
out vec3 approxNormal;
out float aspectRatio;
out float FOVrad;
out vec4 skyCol;

#define FOV_FIXEDPOINT 100.0

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int num = 0;
    num += int(ivec.r);
    num += int(ivec.g) * 255;
    num += int(ivec.b) * 255 * 255;
    return num;
}

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);

	approxNormal = normalize(vec3(0.0, 1.0, 0.0));
    approxNormal.y *= -1;
    aspectRatio = InSize.x / InSize.y;
    texCoord = outPos.xy * 0.5 + 0.5;

    oneTexel = 1.0 / InSize;
    FOVrad = float(decodeInt(texture(TemporalSampler, vec2(0.5 / 16.0, 0.5)).rgb)) / FOV_FIXEDPOINT / 360.0 * 3.1415926535;
    skyCol = texture(TemporalSampler, vec2(9.5 / 16.0, 0.5));
}

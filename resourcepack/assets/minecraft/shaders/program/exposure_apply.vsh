#version 150

in vec4 Position;

uniform sampler2D TemporalSampler;
uniform mat4 ProjMat;

out vec2 texCoord;
out float exposure;

#define EXPOSURE_PRECISION 1000000

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
    texCoord = outPos.xy * 0.5 + 0.5;
    exposure = decodeInt(texture(TemporalSampler, vec2(10.5 / 16.0, 0.5)).rgb) / float(EXPOSURE_PRECISION);
}

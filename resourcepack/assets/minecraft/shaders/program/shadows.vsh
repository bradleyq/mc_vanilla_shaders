#version 150

const float PROJNEAR = 0.05;
const float FPRECISION = 4000000.0;
const float EPSILON = 0.001;

in vec4 Position;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform sampler2D DataSampler;
uniform float Time;

out vec2 texCoord;
out vec2 oneTexel;
out vec3 sunDir;
out mat4 projMat;
out mat4 modelViewMat;
out vec3 chunkOffset;
out vec3 rayDir;
out float near;
out float far;
out mat4 projInv;
out float underWater;
out float validControl;

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

float decodeFloat(vec3 ivec) {
    return decodeInt(ivec) / FPRECISION;
}

vec2 getControl(int index, vec2 screenSize) {
    return vec2(floor(screenSize.x / 2.0) + float(index) * 2.0 + 0.5, 0.5) / screenSize;
}

void main() {
    vec4 outPos = ProjMat * vec4(Position.xy, 0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = Position.xy / OutSize;
    oneTexel = 1.0 / OutSize;

    //simply decoding all the control data and constructing the sunDir, ProjMat, ModelViewMat
    vec2 start = getControl(0, OutSize);
    vec2 inc = vec2(2.0 / OutSize.x, 0.0);

    // ProjMat constructed assuming no translation or rotation matrices applied (aka no view bobbing).
    projMat = mat4(tan(decodeFloat(texture(DataSampler, start + 3.0 * inc).xyz)), decodeFloat(texture(DataSampler, start + 6.0 * inc).xyz), 0.0, 0.0,
            decodeFloat(texture(DataSampler, start + 5.0 * inc).xyz), tan(decodeFloat(texture(DataSampler, start + 4.0 * inc).xyz)), decodeFloat(texture(DataSampler, start + 7.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 8.0 * inc).xyz),
            decodeFloat(texture(DataSampler, start + 9.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 10.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 11.0 * inc).xyz),  decodeFloat(texture(DataSampler, start + 12.0 * inc).xyz),
            decodeFloat(texture(DataSampler, start + 13.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 14.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 15.0 * inc).xyz), 0.0);

    modelViewMat = mat4(decodeFloat(texture(DataSampler, start + 16.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 17.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 18.0 * inc).xyz), 0.0,
            decodeFloat(texture(DataSampler, start + 19.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 20.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 21.0 * inc).xyz), 0.0,
            decodeFloat(texture(DataSampler, start + 22.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 23.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 24.0 * inc).xyz), 0.0,
            0.0, 0.0, 0.0, 1.0);

    near = PROJNEAR;
    far = projMat[3][2] * near / (projMat[3][2] + 2.0 * near);

    chunkOffset = vec3(
            decodeFloat(texelFetch(DataSampler, ivec2(0, 0), 0).xyz),
            decodeFloat(texelFetch(DataSampler, ivec2(1, 0), 0).xyz),
            decodeFloat(texelFetch(DataSampler, ivec2(2, 0), 0).xyz)
    ) * 16;

    sunDir = (inverse(modelViewMat) * vec4(
            decodeFloat(texture(DataSampler, start).xyz),
            decodeFloat(texture(DataSampler, start + inc).xyz),
            decodeFloat(texture(DataSampler, start + 2.0 * inc).xyz),
            1)).xyz;

    sunDir = normalize(sunDir);

    projMat = projMat * modelViewMat;
    projInv = inverse(projMat);
    rayDir = (projInv * vec4(outPos.xy * (far - near), far + near, far - near)).xyz;
    vec4 uwvec = texture(DataSampler, start + 26.0 * inc);
    underWater = uwvec.x;
    validControl = uwvec.w;
}
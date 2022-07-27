#version 330

in vec4 Position;

uniform mat4 ProjMat;
uniform vec2 OutSize;
uniform vec2 AuxSize0;
uniform sampler2D DataSampler;

out vec2 texCoord;
out vec2 oneTexel;
out vec3 sunDir;
out float near;
out float far;
out vec4 fogColor;
out float fogLambda;
out float underWater;
out float raining;
out float cosFOVsq;
out float aspectRatio;
out mat4 Proj;
out mat4 ProjInv;

// moj_import doesn't work in post-process shaders ;_; Felix pls fix
#define FPRECISION 4000000.0
#define PROJNEAR 0.05

#define FLAG_UNDERWATER 1<<0
#define FLAG_RAINING    1<<1

vec2 getControl(int index, vec2 screenSize) {
    return vec2(float(index) + 0.5, 0.5) / screenSize;
}

vec3 encodeInt(int i) {
    int s = int(i < 0) * 128;
    i = abs(i);
    int r = i % 256;
    i = i / 256;
    int g = i % 256;
    i = i / 256;
    int b = i % 128;
    return vec3(float(r) / 255.0, float(g) / 255.0, float(b + s) / 255.0);
}

int decodeInt(vec3 ivec) {
    ivec *= 255.0;
    int s = ivec.b >= 128.0 ? -1 : 1;
    return s * (int(ivec.r) + int(ivec.g) * 256 + (int(ivec.b) - 64 + s * 64) * 256 * 256);
}

vec3 encodeFloat(float f) {
    return encodeInt(int(f * FPRECISION));
}

float decodeFloat(vec3 vec) {
    return decodeInt(vec) / FPRECISION;
}

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    texCoord = Position.xy / OutSize;
    oneTexel = 1.0 / OutSize;

    //simply decoding all the control data and constructing the sunDir, ProjMat, ModelViewMat

    vec2 start = getControl(0, AuxSize0);
    vec2 inc = vec2(1.0 / AuxSize0.x, 0.0);


    // ProjMat constructed fully
    mat4 ProjMat = mat4(tan(decodeFloat(texture(DataSampler, start + 3.0 * inc).xyz)), decodeFloat(texture(DataSampler, start + 6.0 * inc).xyz), 0.0, 0.0,
                            decodeFloat(texture(DataSampler, start + 5.0 * inc).xyz), tan(decodeFloat(texture(DataSampler, start + 4.0 * inc).xyz)), decodeFloat(texture(DataSampler, start + 7.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 8.0 * inc).xyz),
                            decodeFloat(texture(DataSampler, start + 9.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 10.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 11.0 * inc).xyz),  decodeFloat(texture(DataSampler, start + 12.0 * inc).xyz),
                            decodeFloat(texture(DataSampler, start + 13.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 14.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 15.0 * inc).xyz), 0.0);
 
    mat4 ModeViewMat = mat4(decodeFloat(texture(DataSampler, start + 16.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 17.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 18.0 * inc).xyz), 0.0,
                            decodeFloat(texture(DataSampler, start + 19.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 20.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 21.0 * inc).xyz), 0.0,
                            decodeFloat(texture(DataSampler, start + 22.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 23.0 * inc).xyz), decodeFloat(texture(DataSampler, start + 24.0 * inc).xyz), 0.0,
                            0.0, 0.0, 0.0, 1.0);

    sunDir = normalize((inverse(ModeViewMat) * vec4(decodeFloat(texture(DataSampler, start).xyz), 
                                                    decodeFloat(texture(DataSampler, start + inc).xyz), 
                                                    decodeFloat(texture(DataSampler, start + 2.0 * inc).xyz),
                                                    1.0)).xyz);
    near = PROJNEAR;
    far = ProjMat[3][2] * PROJNEAR / (ProjMat[3][2] + 2.0 * PROJNEAR);
    aspectRatio = OutSize.x / OutSize.y;
    cosFOVsq = ProjMat[1][1] * ProjMat[1][1];
    cosFOVsq = cosFOVsq / (1 + cosFOVsq);
    
    Proj = ProjMat * ModeViewMat;
    ProjInv = inverse(Proj);

    fogColor = texture(DataSampler, start + 25.0 * inc);
    fogLambda = float(decodeFloat(texture(DataSampler, start + 27.0 * inc).xyz));

    int flags = int(texture(DataSampler, start + 29.0 * inc).r * 255.0);
    underWater = float((flags & FLAG_UNDERWATER) > 0);
    raining = float((flags & FLAG_RAINING) > 0);
}

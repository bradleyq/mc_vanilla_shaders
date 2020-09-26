#version 120

attribute vec4 Position;

uniform mat4 ProjMat;
uniform vec2 InSize;
uniform float FOV;

varying vec2 texCoord;
varying float aspectRatio;
varying float cosFOVrad;
varying vec3 normal;
varying mat4 gbPI;
varying mat4 gbP;

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);

	normal = normalize(gl_NormalMatrix * normalize(vec3(0.0, 1.0, 0.0)));
    aspectRatio = InSize.x / InSize.y;
    texCoord = outPos.xy * 0.5 + 0.5;

    float FOVrad = FOV / 360.0 * 3.1415926535;
    cosFOVrad = cos(FOVrad);
    float tanFOVrad = tan(FOVrad);
    gbPI = mat4(2.0 * tanFOVrad / aspectRatio, 0.0,             0.0, 0.0,
                0.0,                           2.0 * tanFOVrad, 0.0, 0.0,
                0.0,                           0.0,             0.0, 0.0,
                -tanFOVrad / aspectRatio,     -tanFOVrad,       1.0, 1.0);

    gbP = mat4(aspectRatio / (2.0 * tanFOVrad), 0.0,                     0.0, 0.0,
               0.0,                             1.0 / (2.0 * tanFOVrad), 0.0, 0.0,
               0.5,                             0.5,                     1.0, 0.0,
               0.0,                             0.0,                     0.0, 1.0);
}

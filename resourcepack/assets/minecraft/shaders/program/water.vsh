#version 120

attribute vec4 Position;

uniform mat4 ProjMat;
uniform vec2 InSize;

varying vec2 texCoord;
varying vec2 oneTexel;
varying vec3 approxNormal;
varying float aspectRatio;

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);

	approxNormal = normalize(gl_NormalMatrix * normalize(vec3(0.0, 1.0, 0.0)));
    approxNormal.y *= -1;
    aspectRatio = InSize.x / InSize.y;
    texCoord = outPos.xy * 0.5 + 0.5;

    oneTexel = 1.0 / InSize;
}

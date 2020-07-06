#version 110

attribute vec4 Position;

uniform mat4 ProjMat;
uniform vec2 InSize;

varying mat4 ProjMatInverse;
varying vec2 texCoord;
varying vec2 oneTexel;
varying float aspectRatio;
varying vec3 normal;

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);
    
	normal = normalize(gl_NormalMatrix * normalize(vec3(0.0, 1.0, 0.0)));
    ProjMatInverse = mat4(1.0 / ProjMat[0].x, 0.0, 0.0, 0.0,
                          0.0, 1.0 / ProjMat[1].y, 0.0, 0.0,
                          0.0, 0.0, - ProjMat[3].w / (ProjMat[3].z * ProjMat[2].w), 1.0 / ProjMat[3].z,
                          0, 0, 1.0 / ProjMat[2].w, 0.0);

    oneTexel = 1.0 / InSize;
    aspectRatio = InSize.x / InSize.y;
    texCoord = outPos.xy * 0.5 + 0.5;
}

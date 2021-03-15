#version 120

attribute vec4 Position;

uniform vec2 OutSize;

varying vec2 texCoord;
varying vec2 oneTexel;
varying vec3 normal;
varying vec3 tangent;
varying vec3 bitangent;
varying float aspectRatio;

void main(){
    float x = -1.0; 
    float y = -1.0;
    if (Position.x > 0.001){
        x = 1.0;
    }
    if (Position.y > 0.001){
        y = 1.0;
    }
    gl_Position = vec4(x, y, 0.2, 1.0);
    
    normal = normalize(gl_NormalMatrix * normalize(vec3(0.0, 1.0, 0.0)));
    tangent = normalize(gl_NormalMatrix * normalize(vec3(1.0, 0.0, 0.0)));
    bitangent = normalize(gl_NormalMatrix * normalize(vec3(0.0, 0.0, 1.0)));

    aspectRatio = OutSize.x / OutSize.y;
    oneTexel = 1.0 / OutSize;
    texCoord = Position.xy / OutSize;
}

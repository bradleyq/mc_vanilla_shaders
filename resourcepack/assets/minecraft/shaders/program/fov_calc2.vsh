#version 120

attribute vec4 Position;

uniform vec2 InSize;
uniform vec2 OutSize;

varying vec2 texCoord;
varying vec2 oneTexel;

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

    oneTexel = 1.0 / InSize; // This is REALLY bad practice but i'm lazy
    texCoord = Position.xy / OutSize;
}

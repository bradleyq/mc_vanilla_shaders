#version 150

in vec4 Position;

uniform vec2 OutSize;
uniform mat4 ProjMat;
uniform mat4 ModelViewMat;

out vec2 texCoord;
out vec2 oneTexel;
out vec3 normal;
out vec3 tangent;
out vec3 bitangent;
out float aspectRatio;

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
    
    normal = normalize(transpose(inverse(mat3(ModelViewMat))) * vec3(0.0, 1.0, 0.0));
    tangent = normalize(transpose(inverse(mat3(ModelViewMat))) * vec3(1.0, 0.0, 0.0));
    bitangent = normalize(transpose(inverse(mat3(ModelViewMat))) * vec3(0.0, 0.0, 1.0));

    aspectRatio = OutSize.x / OutSize.y;
    oneTexel = 1.0 / OutSize;
    texCoord = Position.xy / OutSize;
}

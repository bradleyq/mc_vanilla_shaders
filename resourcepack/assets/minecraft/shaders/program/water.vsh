#version 150

in vec4 Position;

uniform mat4 ProjMat;
uniform mat4 ModelViewMat;
uniform vec2 InSize;

out vec2 texCoord;
out vec2 oneTexel;
out vec3 approxNormal;
out float aspectRatio;

void main(){
    vec4 outPos = ProjMat * vec4(Position.xy, 0.0, 1.0);
    gl_Position = vec4(outPos.xy, 0.2, 1.0);

	approxNormal = normalize(transpose(inverse(mat3(ModelViewMat))) * normalize(vec3(0.0, 1.0, 0.0)));
    approxNormal.y *= -1;
    aspectRatio = InSize.x / InSize.y;
    texCoord = outPos.xy * 0.5 + 0.5;

    oneTexel = 1.0 / InSize;
}

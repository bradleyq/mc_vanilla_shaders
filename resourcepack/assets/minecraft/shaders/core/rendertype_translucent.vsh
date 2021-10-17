#version 150

#moj_import <light.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;
uniform float GameTime;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;

out float vertexDistance;
out float isWater;
out vec4 vertexColor;
out vec2 texCoord0;
out vec2 texCoord2;
out vec4 normal;

#define PI 3.14159265359
#define PROJNEAR 0.05

void main() {
    vec3 position = Position + ChunkOffset;
    float animation = GameTime * PI;

    float a1 = 0.0;
    float a2 = 0.0;
    float a3 = 0.0;
    float a4 = 0.0;
    isWater = 0.0;
    vertexDistance = length((ModelViewMat * vec4(Position + ChunkOffset, 1.0)).xyz);
    float far = ProjMat[3][2] * PROJNEAR / (ProjMat[3][2] + 2.0 * PROJNEAR) / 3.0 * sqrt(3);
    vec4 col = Color;
    if (!(col.r == 1.0 && col.g == 1.0 && col.b == 1.0)) { 
        isWater = 1.0;

        // abs(mod(Position.y, 1.0) - 14.2 / 16.0) < 0.001) {
        if (!(mod(Position.y + 0.001, 1.0) < 0.002)) {
            a1 = sin((Position.z * PI / 4.0 + animation * 700)) * 1.0 * (1.0 - smoothstep(0.0, 1.0, vertexDistance / far));
            a2 = cos((Position.z * PI / 8.0 + Position.x * PI / 4.0 + animation * 400) + PI / 13.0) * 1.2 * (1.0 - smoothstep(0.1, 1.0, vertexDistance / far));
            a3 = sin((Position.z * PI / 8.0 - Position.x * PI / 2.0 - animation * 900) - PI / 7.0) * 0.75 * (1.0 - smoothstep(0.0, 0.3, vertexDistance / far));
            a4 = cos((Position.z * PI * 7.0 + Position.x * PI / 2.0 - animation * 870) + PI / 5.0) * 0.75 * (1.0 - smoothstep(0.0, 0.9, vertexDistance / far));
        }
    }

    gl_Position = ProjMat * ModelViewMat * (vec4(position, 1.0) + vec4(0.0, (a1 + a2 + a3 + a4) / 64.0, 0.0, 0.0));

    vertexColor = col * minecraft_sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;
    normal = ProjMat * ModelViewMat * vec4(Normal, 0.0);
}

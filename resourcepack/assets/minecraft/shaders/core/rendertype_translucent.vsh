#version 150

#moj_import <light.glsl>
#moj_import <fog.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;

uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform float GameTime;

out float vertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;

#define PI 3.14159265359
#define PROJNEAR 0.05

void main() {
    vec3 position = Position + ChunkOffset;
    float animation = GameTime * PI;

    float a1 = 0.0;
    float a2 = 0.0;
    float a3 = 0.0;
    float a4 = 0.0;
    float eucDist = length((ModelViewMat * vec4(position, 1.0)).xyz);
    float far = ProjMat[3][2] * PROJNEAR / (ProjMat[3][2] + 2.0 * PROJNEAR) / 3.0 * sqrt(3);
    vec4 col = Color;

    if (!(col.r == col.g && col.g == col.b)) { 

        if (!(mod(Position.y + 0.001, 1.0) < 0.002)) {
            a1 = sin((Position.z * PI / 4.0 + animation * 700)) * 1.0 * (1.0 - smoothstep(0.0, 1.0, eucDist / far));
            a2 = cos((Position.z * PI / 8.0 + Position.x * PI / 4.0 + animation * 400) + PI / 13.0) * 0.75 * (1.0 - smoothstep(0.1, 1.0, eucDist / far));
            a4 = cos((Position.z * PI * 7.0 + Position.x * PI / 2.0 - animation * 870) + PI / 5.0) * 0.25 * (1.0 - smoothstep(0.0, 0.9, eucDist / far));
        }
    }

    gl_Position = ProjMat * ModelViewMat * (vec4(position, 1.0) + vec4(0.0, (a1 + a2 + a3 + a4) / 64.0, 0.0, 0.0));
    vertexDistance = length((ModelViewMat * vec4(position, 1.0)).xyz);

    vertexColor = col * minecraft_sample_lightmap(Sampler2, UV2);
    texCoord0 = UV0;
}

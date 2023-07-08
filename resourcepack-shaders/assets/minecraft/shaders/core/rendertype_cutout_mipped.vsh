#version 330
#define VSH

#moj_import <light.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec3 ChunkOffset;
uniform float GameTime;

out vec4 vertexColor;
out vec4 baseColor;
out vec2 texCoord0;
out vec2 texCoord2;
out vec3 normal;
out vec3 pos;
out vec4 glpos;

void main() {
    vec4 position = vec4(Position + ChunkOffset, 1.0);

    int alpha255 = int(textureLod(Sampler0, UV0, -4).a * 255.0);
    if (getDim(Sampler2) == DIM_OVER && (alpha255 == WAVINGS || alpha255 == WAVINGT)) {
        float scale = (1.0 - smoothstep(222.0, 128.0, float(UV2.y))) * 0.4;
        float animation = GameTime * PI;
        float magnitude = sin(animation * 136 + Position.z * PI / 4.0 + Position.y * PI / 4.0) * 0.04 + 0.04;
        float d0 = sin(animation * 636);
        float d1 = sin(animation * 446);
        float d2 = sin(animation * 570);
        vec3 wave;
        wave.x = sin(animation * 316 + d0 + d1 - Position.x * PI / 4.0 + Position.z * PI / 4.0 + Position.y * PI / 4.0) * magnitude;
        wave.z = sin(animation * 1120 + d1 + d2 + Position.x * PI / 4.0 - Position.z * PI / 4.0 + Position.y * PI / 4.0) * magnitude;
        wave.y = sin(animation * 70 + d2 + d0 + Position.z * PI / 4.0 + Position.y * PI / 4.0 - Position.y * PI / 4.0) * magnitude;
        position.x += scale * 0.5 * (wave.x * 2.0 + wave.y * 1.0);
        position.z += scale * 0.5 * (wave.z * 0.75);
        position.x += scale * 0.03 * sin(sin(animation * 100) * 8.0 + (Position.x + Position.y) / 4.0 * PI);
        position.z += scale * 0.03 * sin(sin(animation * 60) * 6.0 + 978.0 + (Position.z + Position.y) / 4.0 * PI);
    } 
    gl_Position = ProjMat * ModelViewMat * position;

    baseColor = Color;
    vertexColor = minecraft_sample_lightmap_optifine(Sampler2, UV2);
    texCoord0 = UV0;
    texCoord2 = UV2 / 255.0;
    if (getDim(Sampler2) == DIM_OVER) {
        texCoord2.x *= 1.0 - getSun(Sampler2);
    }
    else {
        texCoord2.y = 1.0;
    }
    normal = Normal;
    glpos = gl_Position;
    pos = Position;
}

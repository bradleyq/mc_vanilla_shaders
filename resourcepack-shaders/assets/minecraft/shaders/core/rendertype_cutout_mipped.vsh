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
        position.x += 0.05 * sin(sin(GameTime * 100 * PI) * 8.0 + (Position.x + Position.y) / 4.0 * PI);
        position.z += 0.05 * sin(sin(GameTime * 60 * PI) * 6.0 + 978.0 + (Position.z + Position.y) / 4.0 * PI);
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

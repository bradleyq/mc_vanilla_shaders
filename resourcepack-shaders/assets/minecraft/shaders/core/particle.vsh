#version 330
#define VSH

#moj_import <light.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec2 UV0;
in vec4 Color;
in ivec2 UV2;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec2 texCoord0;
out vec2 texCoord2;
out vec4 baseColor;
out vec4 vertexColor;
out float isBlock;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

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

    // test if current particle is a block particle vs sprite particle
    ivec2 atlasdim = textureSize(Sampler0, 0);
    vec2 scaleduv = UV0 * vec2(atlasdim);
    if (scaleduv != floor(scaleduv) && atlasdim.x * 4 < atlasdim.y) {
        isBlock = 1.0;
    }
    else {
        isBlock = 0.0;
    }
}

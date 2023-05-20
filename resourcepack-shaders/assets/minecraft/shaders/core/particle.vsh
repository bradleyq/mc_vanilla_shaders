#version 330
#define VSH

#moj_import <light.glsl>

in vec3 Position;
in vec2 UV0;
in vec4 Color;
in ivec2 UV2;

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

out vec2 texCoord0;
out vec4 baseColor;
out vec4 vertexColor;
out float isBlock;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    texCoord0 = UV0;
    baseColor = Color;
    vertexColor = minecraft_sample_lightmap(Sampler2, UV2);

    // test if current particle is a block particle vs sprite particle
    ivec2 atlasdim = textureSize(Sampler0, 0);
    vec2 scaleduv = UV0 * vec2(atlasdim);
    if (atlasdim.x == atlasdim.y && floor(scaleduv) != scaleduv) {
        isBlock = 1.0;
    }
    else {
        isBlock = 0.0;
    }
}

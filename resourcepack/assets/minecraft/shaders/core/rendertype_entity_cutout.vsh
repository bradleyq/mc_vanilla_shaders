#version 330
#define VSH

#moj_import <light.glsl>
#moj_import <utils.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV1;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler1;
uniform sampler2D Sampler2;

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;

uniform vec3 Light0_Direction;
uniform vec3 Light1_Direction;

out vec4 vertexColor;
out vec4 baseColor;
out vec4 overlayColor;
out vec2 texCoord0;
out vec2 texCoord2;
out vec3 normal;
out vec4 glpos;

void main() {
    gl_Position = ProjMat * ModelViewMat * vec4(Position, 1.0);

    if (isGUI(ProjMat)) {
        baseColor = minecraft_mix_light(Light0_Direction, Light1_Direction, Normal, Color);
        vertexColor = texelFetch(Sampler2, UV2 / 16, 0);
    } 
    else {
        baseColor = Color;
        vertexColor = minecraft_sample_lightmap(Sampler2, UV2);
    }

    overlayColor = texelFetch(Sampler1, UV1, 0);
    texCoord0 = UV0;
    texCoord2 = UV2 / 255.0;
    texCoord2.x *= 1.0 - getSun(Sampler2);
    normal = getInvWorldMat(Light0_Direction, Light1_Direction) * Normal; // will fail in nether but lighting is softer there
    glpos = gl_Position;
}

#version 330
#define FSH

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform mat4 ProjMat;
uniform sampler2D Sampler0;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec4 baseColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);

    if (!gui) {
        discardControlGLPos(gl_FragCoord.xy, glpos);
    }

    vec4 outColor = textureLod(Sampler0, texCoord0, -4);
    
    if (outColor.a < 0.1) {
        discard;
    }

    outColor.rgb *= (baseColor * ColorModulator).rgb;
    
    if (!gui) {
        outColor = getOutColor(outColor, vertexColor, texCoord2, gl_FragCoord.xy, getDirE(normal));
    }
    else {
        outColor *= vertexColor;
    }

    fragColor = outColor;
}

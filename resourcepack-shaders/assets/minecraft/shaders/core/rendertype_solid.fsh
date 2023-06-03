#version 330
#define FSH

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform sampler2D Sampler0;
uniform sampler2D Sampler2;

uniform vec4 ColorModulator;

in vec4 vertexColor;
in vec4 baseColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    if (inControl(gl_FragCoord.xy, round(gl_FragCoord.x * 2.0 / (glpos.x / glpos.w + 1.0))) == 28) {
        fragColor = vec4(vec3(float(getDim(Sampler2)) / 255.0), 1.0);
    }
    else {
        discardControlGLPos(gl_FragCoord.xy, glpos);
        vec4 outColor = textureLod(Sampler0, texCoord0, -4);

        vec4 baseColorDeband = baseColor;
        baseColorDeband.rgb += 5.0 * vec3(hash21(gl_FragCoord.xy * 1.234 + 0.234)) / 255.0;
        vec4 vertexColorDeband = vertexColor;
        vertexColorDeband.rgb += 2.0 * vec3(hash21(gl_FragCoord.xy * 1.123 + 0.123)) / 255.0;

        outColor.rgb *= (baseColorDeband * ColorModulator).rgb;
        outColor = getOutColor(outColor, vertexColorDeband, texCoord2, gl_FragCoord.xy, getDirB(normal));
        fragColor = outColor;
    }
}

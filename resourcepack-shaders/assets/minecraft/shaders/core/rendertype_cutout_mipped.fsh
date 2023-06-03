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
in vec3 pos;
in vec4 glpos;

out vec4 fragColor;

void main() {
    vec3 realNormal = normalize(cross(dFdx(pos), dFdy(pos)));

    discardControlGLPos(gl_FragCoord.xy, glpos);
    vec4 outColor = textureLod(Sampler0, texCoord0, -4);

    if (outColor.a < ALPHACUTOFF) {
        discard;
    }

    vec4 baseColorDeband = baseColor;

    // moved to fragment shader since Optifine moves grass to cutout_mipped, need to distinguish from leaves
    float up = 255.0;
    float down = 127.0;
    if (getDim(Sampler2) == DIM_NETHER) {
        up = 229.0;
        down = 229.0;
    }
    if (dot(realNormal, vec3(0.0, -1.0, 0.0)) > 0.999) {
        baseColorDeband *= 255.0 / down;
    }
    else if (dot(realNormal, vec3(0.0, 1.0, 0.0)) > 0.999) {
        baseColorDeband *= 255.0 / up;
    }
    else if (abs(dot(realNormal, vec3(1.0, 0.0, 0.0))) > 0.999) {
        baseColorDeband *= 255.0 / 153.0;
    }
    else if (abs(dot(realNormal, vec3(0.0, 0.0, 1.0))) > 0.999) {
        baseColorDeband *= 255.0 / 204.0;
    }
    else if (baseColor.r == baseColor.g && baseColor.g == baseColor.b){
        baseColorDeband = vec4(1.0);
    }
    baseColorDeband = min(baseColorDeband, 1.0);

    baseColorDeband.rgb += 5.0 * vec3(hash21(gl_FragCoord.xy * 1.234 + 0.234)) / 255.0;
    vec4 vertexColorDeband = vertexColor;
    vertexColorDeband.rgb += 2.0 * vec3(hash21(gl_FragCoord.xy * 1.123 + 0.123)) / 255.0;

    outColor.rgb *= (baseColorDeband * ColorModulator).rgb;
    outColor = getOutColor(outColor, vertexColorDeband, texCoord2, gl_FragCoord.xy, getDirB(normal));
    fragColor = outColor;
}

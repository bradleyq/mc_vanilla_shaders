#version 330
#define FSH

#moj_import <fog.glsl>
#moj_import <utils.glsl>

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform sampler2D Sampler0;

uniform vec4 ColorModulator;
uniform float FogStart;
uniform float FogEnd;

in vec4 vertexColor;
in vec4 baseColor;
in vec4 overlayColor;
in vec2 texCoord0;
in vec2 texCoord2;
in vec3 normal;
in vec4 glpos;

out vec4 fragColor;

void main() {
    bool gui = isGUI(ProjMat);
    bool hand = isHand(FogStart, FogEnd);
    bool notpickup = (notPickup(ModelViewMat) || notPickup2(ModelViewMat));
    if (!gui && !hand && notpickup) {
        discardControlGLPos(gl_FragCoord.xy, glpos);
    }
    
    vec4 outColor = texture(Sampler0, texCoord0);

    if (outColor.a < 0.1) {
        discard;
    }

    outColor *= baseColor * ColorModulator;
    outColor.rgb = mix(overlayColor.rgb, outColor.rgb, overlayColor.a);

    if (!gui && !hand && notpickup) {
        outColor = getOutColor(outColor, vertexColor, texCoord2, gl_FragCoord.xy, getDirE(normal));
    }
    else {
        outColor *= vertexColor;
    }
    
    fragColor = outColor;
}

#version 330
#define FSH

#moj_import <utils.glsl>

in vec4 vertexColor;

uniform vec4 ColorModulator;
uniform vec2 ScreenSize;
uniform mat4 ProjMat;

out vec4 fragColor;

#define  _SPACE  0u
#define      _A  488621617u
#define      _B  1025459774u
#define      _C  488129070u
#define      _D  1025033790u
#define      _E  1057964575u
#define      _F  1057964560u
#define      _G  488132142u
#define      _H  589284913u
#define      _I  474091662u
#define      _J  237046348u
#define      _K  589982257u
#define      _L  554189343u
#define      _M  599442993u
#define      _N  597347889u
#define      _O  488162862u
#define      _P  1025458704u
#define      _Q  488166989u
#define      _R  1025459761u
#define      _S  520553534u
#define      _T  1044516996u
#define      _U  588826158u
#define      _V  588818756u
#define      _W  588830378u
#define      _X  581052977u
#define      _Y  581046404u
#define      _Z  1042424351u
#define _PARENL  142876932u
#define _PARENR  136382532u
#define _RSLASH  35787024u
#define _LSLASH  545394753u
#define    _DOT  4u
#define  _COMMA  68u
#define   _HASH  368389098u
#define      _1  147460255u
#define      _2  487657759u
#define      _3  487654958u
#define      _4  73747426u
#define      _5  1057949230u
#define      _6  487540270u
#define      _7  1041305732u
#define      _8  488064558u
#define      _9  488080942u
#define      _0  490399278u
#define _USCORE  31u
#define   _DASH  1015808u
#define   _PLUS  139432064u

#define _CW 5
#define _CH 6
#define _PAD 1

#define PADDING (CHARSCALE * _PAD)
#define CHARWIDTH (CHARSCALE * _CW)
#define CHARHEIGHT (CHARSCALE * _CH)
#define CHARPADDEDWIDTH (CHARWIDTH + PADDING)

#define ORIGIN ivec2(25, 25)
#define CHARSCALE 2
#define CHARCOUNT 21
#define STRING uint[](_V, _A, _N, _I, _L, _L, _A, _SPACE, _E, _N, _V, _SPACE, _3, _DOT, _0, _SPACE, _A, _L, _P, _H, _A)

bool getPixel(uint character, int x, int y) {
    return ((character >> (4 - x + y * 5)) & 1u) == 1u;
}

void main() {
    bool gui = isGUI(ProjMat);
    if (!gui) {
        discardControl(gl_FragCoord.xy, ScreenSize.x);
    }
    
    vec4 color = vertexColor * ColorModulator;

    if (color.a == 0.0) {
        discard;
    }

    if (gui && (length(color.rgb - vec3(16 / 255.0)) < 0.001 || length(color.rgb - vec3(239.0 / 255.0, 50.0 / 255.0, 61.0 / 255.0)) < 0.001)) {
        ivec2 pixel = ivec2(gl_FragCoord.xy);
        ivec2 offset = pixel - ORIGIN;

        if (offset.x >= 0 && offset.y >= 0 && offset.x < (CHARPADDEDWIDTH) * CHARCOUNT - PADDING && offset.y < CHARHEIGHT) {
            uint[] text = STRING;
            int index = offset.x / CHARPADDEDWIDTH;
            offset.x -= index * CHARPADDEDWIDTH;

            if (offset.x < CHARWIDTH) {
                bool pixelOn = getPixel(text[index], offset.x / CHARSCALE, offset.y / CHARSCALE);
                color = pixelOn ? vec4(1.0, 1.0, 1.0, color.a) : color;
            }
        }
    }
    else if (!gui) {
        color = getOutColorSTDALock(color, vec4(1.0), vec2(0.0), gl_FragCoord.xy);
    }
    
    fragColor = color;
}

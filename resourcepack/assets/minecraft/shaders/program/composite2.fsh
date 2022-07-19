#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentSampler;
uniform sampler2D TranslucentSpecSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D PartialCompositeSampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;
in vec2 oneTexel;

out vec4 fragColor;

#define PROJNEAR 0.05
#define PROJFAR 1024.0

float linearizeDepth(float depth) {
    return (2.0 * PROJNEAR * PROJFAR) / (PROJFAR + PROJNEAR - depth * (PROJFAR - PROJNEAR));    
}

vec3 blend( vec3 dst, vec4 src ) {
    return ( dst * ( 1.0 - src.a ) ) + src.rgb;
}

struct Layer {
    vec4 color;
    vec4 spec;
    float depth;
    float op;
};

#define NUM_LAYERS 3

Layer layers[NUM_LAYERS];
int layerIndices[NUM_LAYERS] = int[NUM_LAYERS](0, 1 ,2);
int active_layers = 0;

void try_insert( vec4 color, vec4 spec, float depth, float op ) {
    if ( color.a == 0.0) {
        return;
    }

    layers[active_layers] = Layer(color, spec, depth, op);

    int jj = active_layers++;
    int ii = jj - 1;
    while ( jj > 0 && depth > layers[layerIndices[ii]].depth ) {
        int indexTemp = layerIndices[ii];
        layerIndices[ii] = layerIndices[jj];
        layerIndices[jj] = indexTemp;

        jj = ii--;
    }
}

void main() {
    vec2 realCoord = texCoord;
    if (gl_FragCoord.x < 3.0 && gl_FragCoord.y < 1.0) {
        realCoord.y += oneTexel.y;
    }
    try_insert(texture(TranslucentSampler, realCoord), texture(TranslucentSpecSampler, realCoord), texture(TranslucentDepthSampler, realCoord).r, 0.5);
    try_insert(texture(ParticlesSampler, realCoord), vec4(0.0), texture(ParticlesDepthSampler, realCoord).r, 1.0);
    try_insert(texture(PartialCompositeSampler, realCoord), vec4(0.0), min(min(texture(ItemEntityDepthSampler, realCoord).r, texture(WeatherDepthSampler, realCoord).r), texture(CloudsDepthSampler, realCoord).r), 0.0);

    float diffuseDepth = texture(DiffuseDepthSampler, realCoord).r;
    vec3 OutTexel = texture(DiffuseSampler, realCoord).rgb;
    vec4 ColorTmp = vec4(0.0);
    vec4 SpecTmp  = vec4(0.0);
    for (int ii = 0; ii < active_layers; ++ii) {
        Layer currL = layers[layerIndices[ii]];
        if (currL.depth < diffuseDepth) {
            ColorTmp = currL.color;
            SpecTmp  = currL.spec;
            float op = currL.op;
            if (op < 0.1) {
                float ldepth = linearizeDepth(currL.depth);
                OutTexel = 0.75 * blend(OutTexel, ColorTmp) 
                         + 0.25 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.3, 1.0), clamp(ColorTmp.a, 0.0, 1.0) * (1.0 - smoothstep(PROJFAR / 4.0 - 32.0, PROJFAR / 4.0, ldepth)));
            } else if (op < 0.6 && ColorTmp.a > 0.0) {
                float ldepth = linearizeDepth(currL.depth);
                OutTexel = 0.5 * blend(OutTexel, ColorTmp)
                         + 0.5 * OutTexel * mix(vec3(1.0), ColorTmp.rgb / clamp(max(ColorTmp.r, max(ColorTmp.g, ColorTmp.b)), 0.1, 1.0), clamp(ColorTmp.a, 0.0, 1.0) * (1.0 - smoothstep(PROJFAR / 4.0 - 32.0, PROJFAR / 4.0, ldepth)));
                OutTexel = mix(OutTexel, SpecTmp.rgb, SpecTmp.a);
            } 
            else {
                OutTexel = mix(OutTexel, ColorTmp.rgb, ColorTmp.a);
            }
        }
    }

    fragColor = vec4(OutTexel, 1.0);
}

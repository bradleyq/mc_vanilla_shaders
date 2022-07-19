#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform sampler2D TranslucentDepthSampler;
uniform sampler2D ItemEntitySampler;
uniform sampler2D ItemEntityDepthSampler;
uniform sampler2D ParticlesSampler;
uniform sampler2D ParticlesDepthSampler;
uniform sampler2D WeatherSampler;
uniform sampler2D WeatherDepthSampler;
uniform sampler2D CloudsSampler;
uniform sampler2D CloudsDepthSampler;

in vec2 texCoord;

out vec4 fragColor;

struct Layer {
    vec4 color;
    float depth;
    float op;
};

#define CLOUD_MULT vec4(1.25, 1.25, 1.25, 0.75)
#define ALPHA_SCALE 0.2
#define NUM_LAYERS 5

Layer layers[NUM_LAYERS];
int layerIndices[NUM_LAYERS] = int[NUM_LAYERS](0, 1 ,2, 3, 4);
int active_layers = 0;

void try_insert( vec4 color, float depth, float op ) {
    if ( color.a == 0.0) {
        return;
    }

    layers[active_layers] = Layer(color, depth, op);

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
    try_insert(texture(DiffuseSampler, texCoord), texture(TranslucentDepthSampler, texCoord).r, 0.0);
    try_insert(texture(ItemEntitySampler, texCoord), texture(ItemEntityDepthSampler, texCoord).r, 1.0);
    try_insert(texture(ParticlesSampler, texCoord), texture(ParticlesDepthSampler, texCoord).r, 0.0);
    try_insert(texture(WeatherSampler, texCoord), texture(WeatherDepthSampler, texCoord).r, 1.0);
    try_insert(texture(CloudsSampler, texCoord), texture(CloudsDepthSampler, texCoord).r, 1.0);

    float diffuseDepth = texture(DiffuseDepthSampler, texCoord).r;
    vec4 outColor = vec4(0.0);
    vec4 ColorTmp = vec4(0.0);
    float op = 0.0;
    for (int ii = 0; ii < active_layers; ++ii) {
        Layer currL = layers[layerIndices[ii]];
        if(currL.depth < diffuseDepth) {
            ColorTmp = currL.color;
            op = currL.op;
            if (op > 0.5) {
                if (ColorTmp.a > 0.0) {
                    outColor = vec4(mix(mix(ColorTmp.rgb, outColor.rgb, outColor.a), ColorTmp.rgb, ColorTmp.a), 1.0 - (1.0 - ColorTmp.a) * (1.0 - outColor.a));
                }
            } else {
                outColor = vec4(mix(outColor.rgb, ColorTmp.rgb, ColorTmp.a * ALPHA_SCALE), outColor.a) * float(ColorTmp.a < 1.0);
            }
        }
    }
    
    fragColor = outColor;
}

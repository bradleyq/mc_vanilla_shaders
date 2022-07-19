#version 150

uniform sampler2D DiffuseSampler;
uniform sampler2D DiffuseDepthSampler;
uniform vec2 OutSize;
uniform float Time;
uniform float DirX;

in vec2 texCoord;
in vec2 oneTexel;
in float fov;

out vec4 fragColor;

#define PROJNEAR 0.05
#define PROJFAR 1024.0

float linearizeDepth(float depth) {
    return (2.0 * PROJNEAR * PROJFAR) / (PROJFAR + PROJNEAR - depth * (PROJFAR - PROJNEAR));    
}

#define BLF_SAMPLES 4.0
#define BLF_SIGV_MIN 0.0
#define BLF_SIGV_MAX 0.03
#define BLF_SIGV_MULT 0.000002
#define BLF_STRIDE_MIN 0.1
#define BLF_STRIDE_MAX 2.0
#define BLF_STRIDE_MULT 0.07
#define BLF_STD_MIN 1.0
#define BLF_STD_MAX 10.0
#define BLF_STD_MULT 0.2

float Gaussian(float sigma, float x)
{
    return exp(-(x*x) / (2.0 * sigma*sigma));
}

vec3 JoinedBilateralGaussianBlur(vec2 uv, float sigX, float sigY, float sigV, float stride, bool x)
{   

    float total = 0.0;
    vec3 ret = vec3(0.0);

    float depth = texture(DiffuseDepthSampler, uv).r;
    
    for (float i = -BLF_SAMPLES * stride; i <= BLF_SAMPLES * stride; i+= stride)
    {
        float fg = Gaussian( sigY, i );

        float offsetx = x ? i * oneTexel.x : 0.0;
        float offsety = x ? 0.0 : i * oneTexel.y;

        float sd = texture(DiffuseDepthSampler, uv + vec2(offsetx, offsety)).r;
                    
        float fv = Gaussian( sigV, abs(sd - depth) );
        
        total += fg*fv;
        ret += fg*fv * texture(DiffuseSampler, uv + vec2(offsetx, offsety / 2.0)).rgb;
    }
        
    return ret / total;
}

void main() {
    vec4 outColor = vec4(0.0);

    float ratio = linearizeDepth(texture(DiffuseDepthSampler, texCoord).r) / PROJFAR  * (fov / 70.0);
    float sigV = clamp(BLF_SIGV_MULT / ratio, BLF_SIGV_MIN, BLF_SIGV_MAX);
    float stride = clamp(BLF_STRIDE_MULT * OutSize.y / 1440.0 / ratio, BLF_STRIDE_MIN, BLF_STRIDE_MAX);
    float st_dev = clamp(BLF_STD_MULT * OutSize.y / 1440.0 / ratio, BLF_STD_MIN, BLF_STD_MAX);

    outColor = vec4(JoinedBilateralGaussianBlur(texCoord, st_dev, st_dev, sigV, stride, DirX > 0.5), 1.0);

    fragColor = outColor;
}

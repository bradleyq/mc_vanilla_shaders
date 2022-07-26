#version 330

#define MINECRAFT_LIGHT_POWER   (0.6)
#define MINECRAFT_AMBIENT_LIGHT (0.4)

vec4 minecraft_mix_light(vec3 lightDir0, vec3 lightDir1, vec3 normal, vec4 color) {
    lightDir0 = normalize(lightDir0);
    lightDir1 = normalize(lightDir1);
    float light0 = max(0.0, dot(lightDir0, normal));
    float light1 = max(0.0, dot(lightDir1, normal));
    float lightAccum = min(1.0, (light0 + light1) * MINECRAFT_LIGHT_POWER + MINECRAFT_AMBIENT_LIGHT);
    return vec4(color.rgb * lightAccum, color.a);
}

#define NCOLOR normalize(vec3(42.0 / 255.0, 42.0 / 255.0, 72.0 / 255.0))
#define DCOLOR normalize(vec3(1.0))

float getSun(sampler2D lightMap) {
    vec3 sunlight = normalize(texture(lightMap, vec2(0.5 / 16.0, 15.5 / 16.0)).rgb);
    return clamp(pow(length(sunlight - NCOLOR) / length(DCOLOR - NCOLOR), 4.0), 0.0, 1.0);
}

vec4 minecraft_sample_lightmap(sampler2D lightMap, ivec2 uv) {
    float sun = 1.0 - uv.y / 256.0 * getSun(lightMap);

    return texture(lightMap, clamp(uv / 256.0, vec2(0.8 / 16.0), vec2(15.5 / 16.0))) * mix(vec4(1.0), vec4(1.2, 0.80, 0.45, 1.0), uv.x / 256.0 * sun); // x is torch, y is sun
}

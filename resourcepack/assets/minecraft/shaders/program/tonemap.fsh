#version 120

uniform sampler2D DiffuseSampler;

varying vec2 texCoord;

#define TonemapExposure 1.1 
#define TonemapWhiteCurve 70.4 
#define TonemapLowerCurve 1.0 
#define TonemapUpperCurve 0.5 

#define Saturation 1.00 
#define Vibrance 1.30 

vec3 BSLTonemap(vec3 x){
	x = TonemapExposure * x;
	x = x / pow(pow(x, vec3(TonemapWhiteCurve)) + 1.0, vec3(1.0 / TonemapWhiteCurve));
	x = pow(x, mix(vec3(TonemapLowerCurve), vec3(TonemapUpperCurve), sqrt(x)));
	return x;
}

vec3 colorSaturation(vec3 x){
	float grayv = (x.r + x.g + x.b) / 3.0;
	float grays = grayv;
	if (Saturation < 1.0) grays = dot(x,vec3(0.299, 0.587, 0.114));

	float mn = min(x.r, min(x.g, x.b));
	float mx = max(x.r, max(x.g, x.b));
	float sat = (1.0 - (mx - mn)) * (1.0-mx) * grayv * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	x = mix(x,mix(x,lightness, 1.0 - Vibrance), sat);
	x = mix(x, lightness, (1.0 - lightness) * (2.0 - Vibrance) / 2.0 * abs(Vibrance - 1.0));

	return x * Saturation - grays * (Saturation - 1.0);
}

void main() {

    vec3 color = texture2D(DiffuseSampler, texCoord).rgb;
    color = colorSaturation(color);
    color = BSLTonemap(color);

    gl_FragColor = vec4(color, 1.0);
}

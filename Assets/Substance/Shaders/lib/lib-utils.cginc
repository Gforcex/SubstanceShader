//Painter doesn't apply any tone mapping except the optional one applied by Yebis. 
//If you decide to do some tone mapping in your shader, it will be applied before Yebis tone mapping.
//Perform the S - curve tone mapping based on the parameters sigma and n.
float3 tonemapSCurve(float3 value, float sigma, float n)
{
	float3 pow_value = pow(value, n);
	return pow_value / (pow_value + pow(sigma, n));
}

//sRGB conversions
//These are the conversions used in Painter.
//You can override the automatic linear->sRGB conversion in the viewport by putting this line in your custom shader :
//#define DISABLE_FRAMEBUFFER_SRGB_CONVERSION
//and doing your own custom conversion.
//sRGB to linear color conversion.Scalar version.
float sRGB2linear(float x)
{
	return x <= 0.04045 ?
		x * 0.0773993808 : // 1.0/12.92
		pow((x + 0.055) / 1.055, 2.4);
}

//sRGB to linear color conversion.RGB version.
float3 sRGB2linear(float3 rgb)
{
	return float3(
		sRGB2linear(rgb.r),
		sRGB2linear(rgb.g),
		sRGB2linear(rgb.b));
}


//sRGB to linear color conversion.RGB + Alpha version.
float4 sRGB2linear(float4 rgba)
{
	return float4(sRGB2linear(rgba.rgb), rgba.a);
}


//Linear to sRGB color conversion.Scalar version.
float linear2sRGB(float x)
{
	return x <= 0.0031308 ?
		12.92 * x :
		1.055 * pow(x, 0.41666) - 0.055;
}


//Linear to sRGB color conversion.RGB version.
float3 linear2sRGB(float3 rgb)
{
	return float3(
		linear2sRGB(rgb.r),
		linear2sRGB(rgb.g),
		linear2sRGB(rgb.b));
}


//Linear to sRGB color conversion.RGB + Alpha version.
float4 linear2sRGB(float4 rgba)
{
	return float4(linear2sRGB(rgba.rgb), rgba.a);
}

//: param auto conversion_linear_to_srgb
uniform bool convert_to_srgb_opt;

//Linear to sRGB color conversion optional.Scalar version.
float linear2sRGBOpt(float x)
{
	return convert_to_srgb_opt ? linear2sRGB(x) : x;
}

//Linear to sRGB color conversion optional.RGB version.
float3 linear2sRGBOpt(float3 rgb)
{
	return convert_to_srgb_opt ? linear2sRGB(rgb) : rgb;
}

//Linear to sRGB color conversion optional.RGB + Alpha version.
float4 linear2sRGBOpt(float4 rgba)
{
	return convert_to_srgb_opt ? linear2sRGB(rgba) : rgba;
}


//Color conversion.Scalar version.
uniform int output_conversion_method;
float convertOutput(float x)
{
	if (output_conversion_method == 0) return x;
	else if (output_conversion_method == 1) return linear2sRGB(x);
	else return sRGB2linear(x);
}

//Color conversion.RGB version.
vec3 convertOutput(vec3 rgb)
{
	if (output_conversion_method == 0) return rgb;
	else if (output_conversion_method == 1) return linear2sRGB(rgb);
	else return sRGB2linear(rgb);
}

//Color conversion.RGB + Alpha version.
vec4 convertOutput(vec4 rgba)
{
	if (output_conversion_method == 0) return rgba;
	else if (output_conversion_method == 1) return linear2sRGB(rgba);
	else return sRGB2linear(rgba);
}

//Dithering
//These are some helpers to add dithering to shaders.

//Bayer Matrix for dithering mode
const int ditherMask[64] = {
	0, 32, 8, 40, 2, 34, 10, 42,
	48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38,
	60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41,
	51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37,
	63, 31, 55, 23, 61, 29, 53, 21
};

//Get an uniform value based on pixel coordinates.
float getDitherThreshold(float2 coords)
{
	float2 c = float2(mod(coords, 8));
	return (ditherMask[c.y * 8 + c.x] + 0.5) / 64;

	//return bayerMatrix8(coords);
}


float4 RGB2Gray(float4 rgba)
{
	float gray = 0.299 * rgba.r + 0.587 * rgba.g + 0.114 * rgba.b;
	return float4(gray.xxx, rgba.a);
}

//Remove AO and shadows on glossy metallic surfaces(close to mirrors)
float specularOcclusionCorrection(float diffuseOcclusion, float metallic, float roughness)
{
	return mix(diffuseOcclusion, 1.0, metallic * (1.0 - roughness) * (1.0 - roughness));
}
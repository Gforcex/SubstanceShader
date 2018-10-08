
#include "lib-defines.cginc"

//: param auto channel_height
uniform sampler2D height_texture;
//: param auto channel_normal
uniform sampler2D normal_texture;
//: param auto texture_normal
uniform sampler2D base_normal_texture;
//: param auto channel_normal_is_set
uniform bool channel_normal_is_set;
//: param auto normal_blending_mode
uniform int normal_blending_mode;

//Used to invert the Y axis of the normal map
//: param auto normal_y_coeff
uniform float base_normal_y_coeff;
//: param auto channel_height_size
//uniform float4 height_size; // width, height, width_inv, height_inv
uniform float4 height_texture_TexelSize;

//: param custom {
//:   "default": 1.0,
//:   "label": "Height force",
//:   "min": 0.01,
//:   "max": 10.0,
//:   "group": "Common Parameters"
//: }
uniform float height_force;

#define HEIGHT_FACTOR  400.0

//Perform the blending between 2 normal maps
//This is based on Whiteout blending http ://blog.selfshadow.com/publications/blending-in-detail/
float3 normalBlend(float3 baseNormal, float3 overNormal)
{
	return normalize(float3(
		baseNormal.xy + overNormal.xy,
		baseNormal.z  * overNormal.z));
}

//Perform a detail oriented blending between 2 normal maps
//This is based on Detail Oriented blending http ://blog.selfshadow.com/publications/blending-in-detail/
float3 normalBlendOriented(float3 baseNormal, float3 overNormal)
{
	baseNormal.z += 1.0;
	overNormal.xy = -overNormal.xy;
	return normalize(baseNormal * dot(baseNormal, overNormal) -
		overNormal * baseNormal.z);
}

//Returns a normal flattened by an attenuation factor
float3 normalFade(float3 normal, float attenuation)
{
	if (attenuation<1.0 && normal.z<1.0)
	{
		float phi = attenuation * acos(normal.z);
		normal.xy *= 1.0 / sqrt(1.0 - normal.z*normal.z) * sin(phi);
		normal.z = cos(phi);
	}

	return normal;
}

//Unpack a normal w / alpha channel
float3 normalUnpack(float4 normal_alpha, float y_coeff)
{
	if (normal_alpha.a == 0.0)
	{
		return float3(0.0, 0.0, 1.0);
	}

	// Attenuation in function of alpha
	float3 normal = normal_alpha.xyz / normal_alpha.a * 2.0 - 1.0;
	normal.y *= y_coeff;
	normal.z = max(1e-3, normal.z);
	normal = normalize(normal);
	normal = normalFade(normal, normal_alpha.a);

	return normal;
}


//Unpack a normal w / alpha channel, no Y invertion
float3 normalUnpack(float4 normal_alpha)
{
	return normalUnpack(normal_alpha, 1.0);
}


//Compute the tangent space normal from document's height channel
float3 normalFromHeight(float2 tex_coord, float height_force)
{
	// Normal computation using height map
	float h_r = textureOffset(height_texture, tex_coord, float2(1, 0)).r;
	float h_l = textureOffset(height_texture, tex_coord, float2(-1, 0)).r;
	float h_t = textureOffset(height_texture, tex_coord, float2(0, 1)).r;
	float h_b = textureOffset(height_texture, tex_coord, float2(0, -1)).r;
	float h_rt = textureOffset(height_texture, tex_coord, float2(1, 1)).r;
	float h_lt = textureOffset(height_texture, tex_coord, float2(-1, 1)).r;
	float h_rb = textureOffset(height_texture, tex_coord, float2(1, -1)).r;
	float h_lb = textureOffset(height_texture, tex_coord, float2(-1, -1)).r;
	float4 height_size = height_texture_TexelSize;

	float2 dh_dudv = (0.5 * height_force) * height_size.xy * float2(
		2.0*(h_l - h_r) + h_lt - h_rt + h_lb - h_rb,
		2.0*(h_b - h_t) + h_rb - h_rt + h_lb - h_lt);

	return normalize(float3(dh_dudv, HEIGHT_FACTOR));
}


//Helper to compute the tangent space normal from base normal and a height value, and an optional detail normal.
float3 getTSNormal(float2 tex_coord, float3 normalFromHeight)
{
	//TEMP
	//return normalUnpack(tex2D(base_normal_texture, tex_coord), base_normal_y_coeff);

	float3 normal = normalBlendOriented(
		normalUnpack(tex2D(base_normal_texture, tex_coord), base_normal_y_coeff),
		normalFromHeight);

	if (channel_normal_is_set) {
		float3 channelNormal = normalUnpack(tex2D(normal_texture, tex_coord));
		if (normal_blending_mode == BlendingMode_Replace) {
			normal = normalBlendOriented(normalFromHeight, channelNormal);
		}
		else if (normal_blending_mode == BlendingMode_NM_Combine) {
			normal = normalBlendOriented(normal, channelNormal);
		}
	}

	return normal;
}


//Helper to compute the tangent space normal from base normal and height, and an optional detail normal.
float3 getTSNormal(float2 tex_coord)
{
	float3 normalH = normalFromHeight(tex_coord, height_force);
	return getTSNormal(tex_coord, normalH);
}


//Helper to compute the world space normal from tangent space base normal.
float3 computeWSBaseNormal(float2 tex_coord, float3 tangent, float3 bitangent, float3 normal)
{
	float3 normal_vec = normalUnpack(tex2D(normal_texture, tex_coord), base_normal_y_coeff);
	return normalize(
		normal_vec.x * tangent +
		normal_vec.y * bitangent +
		normal_vec.z * normal
	);
}


//Helper to compute the world space normal from tangent space normal given by getTSNormal helpers, and local frame of the mesh.
float3 computeWSNormal(float2 tex_coord, float3 tangent, float3 bitangent, float3 normal)
{
	float3 normal_vec = getTSNormal(tex_coord);
	return normalize(
		normal_vec.x * tangent +
		normal_vec.y * bitangent +
		normal_vec.z * normal
	);

	//return normalize( float3(
	//	dot(normal_vec, float3(tangent.x, bitangent.x, normal.x)),
	//	dot(normal_vec, float3(tangent.y, bitangent.y, normal.y)),
	//	dot(normal_vec, float3(tangent.z, bitangent.z, normal.z))
	//));
}
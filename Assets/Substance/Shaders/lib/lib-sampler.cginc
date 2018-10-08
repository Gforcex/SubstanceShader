#include "lib-defines.cginc"

#define DEFAULT_BASE_COLOR  0.5
#define DEFAULT_ROUGHNESS  0.3
#define DEFAULT_METALLIC  0.0
#define DEFAULT_OPACITY  1.0
#define DEFAULT_AO  1.0
#define DEFAULT_SPECULAR_LEVEL  0.5
#define DEFAULT_HEIGHT  0.0
#define DEFAULT_DISPLACEMENT  0.0
#define DEFAULT_SCATTERING  0.0

//AO map.
//: param auto ao_blending_mode
uniform int ao_blending_mode;
//: param auto texture_ao
uniform sampler2D base_ao_tex;
//: param auto channel_ao
uniform sampler2D ao_tex;
//: param auto channel_ao_is_set
uniform bool channel_ao_is_set;

//: param custom {
//:   "default": 0.75,
//:   "label": "AO Intensity",
//:   "min": 0.00,
//:   "max": 1.0,
//:   "group": "Common Parameters"
//: }
uniform float ao_intensity;


//: param auto shadow_mask_enable
uniform bool sm_enable;
//: param auto shadow_mask_opacity
uniform float sm_opacity;
//: param auto shadow_mask
uniform sampler2D sm_tex;
//: param auto screen_size
uniform float4 screen_size;

//Return sampled glossiness or a default value
float getGlossiness(sampler2D glossiness_tex, float2 tex_coord)
{
	float2 glossiness_a = tex2D(glossiness_tex, tex_coord).rg;
	return glossiness_a.r + (1.0 - DEFAULT_ROUGHNESS) * (1.0 - glossiness_a.g);
}

//Return sampled roughness or a default value
float getRoughness(sampler2D roughness_tex, float2 tex_coord)
{
	float2 roughness_a = tex2D(roughness_tex, tex_coord).rg;
	return roughness_a.r + DEFAULT_ROUGHNESS * (1.0 - roughness_a.g);
}

//Return sampled metallic or a default value
float getMetallic(sampler2D metallic_tex, float2 tex_coord)
{
	float2 metallic_a = tex2D(metallic_tex, tex_coord).rg;
	return metallic_a.r + DEFAULT_METALLIC * (1.0 - metallic_a.g);
}

//Return sampled opacity or a default value
float getOpacity(sampler2D opacity_tex, float2 tex_coord)
{
	float2 opacity_a = tex2D(opacity_tex, tex_coord).rg;
	return opacity_a.r + DEFAULT_OPACITY * (1.0 - opacity_a.g);
}

//Return sampled height or a default value
float getHeight(sampler2D height_tex, float2 tex_coord)
{
	float2 height_a = tex2D(height_tex, tex_coord).rg;
	return height_a.r + DEFAULT_HEIGHT * (1.0 - height_a.g);
}

//Return sampled displacement or a default value
float getDisplacement(sampler2D displacement_tex, float2 tex_coord)
{
	float2 displacement_a = tex2D(displacement_tex, tex_coord).rg;
	return displacement_a.r + DEFAULT_DISPLACEMENT * (1.0 - displacement_a.g);
}

//Return ambient occlusion
float getAO(float2 tex_coord, bool is_premult)
{
	float2 ao_lookup = tex2D(base_ao_tex, tex_coord).ra;
	float ao = ao_lookup.x + DEFAULT_AO * (1.0 - ao_lookup.y);

	if (channel_ao_is_set) {
		ao_lookup = tex2D(ao_tex, tex_coord).rg;
		if (!is_premult) ao_lookup.x *= ao_lookup.y;
		float channel_ao = ao_lookup.x + DEFAULT_AO * (1.0 - ao_lookup.y);
		if (ao_blending_mode == BlendingMode_Replace) {
			ao = channel_ao;
		}
		else if (ao_blending_mode == BlendingMode_Multiply) {
			ao *= channel_ao;
		}
	}

	// Modulate AO value by AO_intensity
	return lerp(1.0, ao, ao_intensity);
}

//Helper to get ambient occlusion for shading
float getAO(float2 tex_coord)
{
	return getAO(tex_coord, true);
}

//Return specular level
float getSpecularLevel(sampler2D specularlevel_tex, float2 tex_coord)
{
	float2 specularlevel_a = tex2D(specularlevel_tex, tex_coord).rg;
	return specularlevel_a.r + DEFAULT_SPECULAR_LEVEL * (1.0 - specularlevel_a.g);
}

//Fetch the shadowing factor(screen - space)
float getShadowFactor(float2 shadowCoord)
{
	float shadowFactor = 1.0;

	if (sm_enable) {
		float2 screenCoord = (shadowCoord.xy * float2(screen_size.z, screen_size.w));
		float2 shadowSample = tex2D(sm_tex, screenCoord).xy;
		// shadowSample.x / shadowSample.y is the normalized shadow factor.
		// shadowSample.x may already be normalized, shadowSample.y contains 0.0 in this case.
		shadowFactor = shadowSample.y == 0.0 ? shadowSample.x : shadowSample.x / shadowSample.y;
	}

	return lerp(1.0, shadowFactor, sm_opacity);
}

//Return sampled base color or a default value
float3 getBaseColor(sampler2D diffuse_tex, float2 tex_coord)
{
	float4 out_color = tex2D(diffuse_tex, tex_coord);
	return out_color.rgb + DEFAULT_BASE_COLOR * (1.0 - out_color.a);
}

//Return sampled diffuse color or a default value
float3 getDiffuse(sampler2D diffuse_tex, float2 tex_coord)
{
	return getBaseColor(diffuse_tex, tex_coord);
}

//Return sampled specular color or a default value
float3 getSpecularColor(sampler2D specular_tex, float2 tex_coord)
{
	float4 out_color = tex2D(specular_tex, tex_coord).rgba;
	float3 specColor = out_color.rgb + DEFAULT_BASE_COLOR * (1.0 - out_color.a);
	float3 defaultF0 = lerp(0.04, specColor, DEFAULT_METALLIC);
	return lerp(specColor, defaultF0, (1.0 - out_color.a));
}

//Generate diffuse color from base color and metallic factor
float3 generateDiffuseColor(float3 baseColor, float metallic)
{
	return baseColor * (1.0 - metallic);
}


//Generate specular color from dielectric specular level, base color and metallic factor
float3 generateSpecularColor(float specularLevel, float3 baseColor, float metallic)
{
	return lerp(0.08 * specularLevel, baseColor, metallic);
}

//Generate specular color from base color and metallic factor, using default specular level(0.04) for dielectrics
float3 generateSpecularColor(float3 baseColor, float metallic)
{
	return lerp(0.04, baseColor, metallic);
}


//Return sampled scattering value or a default value
float getScattering(sampler2D scattering_tex, float2 tex_coord)
{
	float2 out_scattering = tex2D(scattering_tex, tex_coord).rg;
	return out_scattering.r + DEFAULT_SCATTERING * (1.0 - out_scattering.g);
}
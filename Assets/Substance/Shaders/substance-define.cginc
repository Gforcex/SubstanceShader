

struct V2F {
	float4 pos				  :SV_POSITION;
	float3 normal             :TEXCOORD0;   // interpolated normal
	float3 tangent            :TEXCOORD1;   // interpolated tangent
	float3 bitangent          :TEXCOORD2;   // interpolated bitangent
	float3 position           :TEXCOORD3;   // interpolated position
	float4 color	          :TEXCOORD4;   // interpolated vertex colors (color0)
	float2 tex_coord          :TEXCOORD5;   // interpolated tex2D coordinates (uv0)
	UNITY_FOG_COORDS(6)
};

//surface shader
// // fragment opacity. default value: 1.0
// void alphaOutput(float);
// // diffuse lighting contribution. default value: vec3(0.0)
// void diffuseShadingOutput(vec3);
// // specular lighting contribution. default value: vec3(0.0)
// void specularShadingOutput(vec3);
// // color emitted by the fragment. default value: vec3(0.0)
// void emissiveColorOutput(vec3);
// // fragment color. default value: vec3(1.0)
// void albedoOutput(vec3);
// // subsurface scattering properties, see lib-sss.glsl for details. default value: vec4(0.0)
// void sssCoefficientsOutput(vec4);


//: param auto channel_basecolor
uniform sampler2D basecolor_tex;
//: param auto channel_roughness
uniform sampler2D roughness_tex;
//: param auto channel_metallic
uniform sampler2D metallic_tex;
//: param auto channel_specularlevel
uniform sampler2D specularlevel_tex;


////////////////////////////////////////////

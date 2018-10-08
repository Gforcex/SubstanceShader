Shader "pbr-metal-rough"
{
	Properties
	{
		basecolor_tex("basecolor", 2D) = "white" {}
		opacity_tex("opacity", 2D) = "white" {}
		alpha_threshold("alpha_threshold", Range(0,1)) = 0.33
		alpha_dither("alpha_dither", Float) = 0

		height_texture("height", 2D) = "white" {}
		normal_texture("normal", 2D) = "bump" {}
		base_normal_texture("base_normal", 2D) = "bump" {}

		roughness_tex("roughness", 2D) = "white" {}
		metallic_tex("metallic", 2D) = "white" {}
		specularlevel_tex("specularlevel", 2D) = "black" {}

		emissive_tex("emissive", 2D) = "black" {}
		emissive_intensity("emissive_intensity", Range(0,100)) = 1

		ao_tex("ao", 2D) = "white" {}
		base_ao_tex("base_ao", 2D) = "white" {}
		ao_intensity("ao_intensity", Range(0,1)) = 0.75

		sss_tex("sss", 2D) = "black" {}	
		sssScale("sssScale", Range(0.01, 1)) = 0.5
		sssColor("sssScale", Color) = (0.701, 0.301, 0.305)
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			Name "FORWARD"
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma exclude_renderers gles d3d11_9x
			//#pragma multi_compile_fwdbase
			#pragma target 5.0
			#pragma multi_compile _SUBSTANCE _UE4BRDF _REALTIME

			#include "UnityCG.cginc"
			#include "glsl2unitycg.cginc"
			#include "substance-define.cginc"
			#include "lib/lib-utils.cginc"
			#include "lib/lib-pbr.cginc"
			#include "lib/lib-sampler.cginc"
			#include "lib/lib-sss.cginc"
			#include "IBL.cginc"

			V2F vert (appdata_full v)
			{
				V2F o;
				UNITY_INITIALIZE_OUTPUT(V2F, o);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.tex_coord = v.texcoord;
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
				o.bitangent = cross(o.normal.xyz, o.tangent.xyz) * v.tangent.w * unity_WorldTransformParams.w;
				o.position  = mul(unity_ObjectToWorld, v.vertex).xyz;
				//o.position = v.vertex.xyz;
				o.color = v.color;
				
				//UNITY_TRANSFER_SHADOW(o, v.texcoord1.xy);
				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}

			float global_roughness;
			void getAllValue(float2 tex_coord, out float3 baseColor, out float roughness, out float metallic, out float specularLevel, out float occlusion)
			{
				baseColor = tex2D(basecolor_tex, tex_coord).rgb;
				roughness = clamp(tex2D(roughness_tex, tex_coord).r * global_roughness, 0, 1);
				metallic = tex2D(metallic_tex, tex_coord).r;
				specularLevel = tex2D(specularlevel_tex, tex_coord).r;
				occlusion = tex2D(base_ao_tex, tex_coord).r;
			}
			
			float4 shade(V2F inputs, float cullFace)
			{
				// Apply parallax occlusion mapping if possible
				float3 viewTS = worldSpaceToTangentSpace(getEyeVec(inputs.position), inputs);
				//inputs.tex_coord += getParallaxOffset(inputs.tex_coord, viewTS);

				float3 baseColor;
				float roughness, metallic, specularLevel, occlusion;
				getAllValue(inputs.tex_coord, baseColor, roughness, metallic, specularLevel, occlusion);

				// Fetch material parameters, and conversion to the specular/roughness model
				//float roughness = getRoughness(roughness_tex, inputs.tex_coord);
				//vec3 baseColor = getBaseColor(basecolor_tex, inputs.tex_coord);
				//float metallic = getMetallic(metallic_tex, inputs.tex_coord);
				//float specularLevel = getSpecularLevel(specularlevel_tex, inputs.tex_coord);
				// Get detail (ambient occlusion) and global (shadow) occlusion factors
				//float occlusion = getAO(inputs.tex_coord) * getShadowFactor();
				float specOcclusion = specularOcclusionCorrection(occlusion, metallic, roughness);
				vec3 diffColor = generateDiffuseColor(baseColor, metallic);
				vec3 specColor = generateSpecularColor(specularLevel, baseColor, metallic);

				// Feed parameters for a physically based BRDF integration
				//return pbrComputeBRDF(inputs, cullFace, diffColor, specColor, roughness, occlusion);
				LocalVectors vectors = computeLocalFrame(inputs, cullFace);

				// Feed parameters for a physically based BRDF integration
				float3 col = 0;
				col += pbrComputeEmissive(emissive_tex, inputs.tex_coord);
				col += pbrComputeDiffuse(vectors.normal, diffColor, occlusion);
				col += getSSSCoefficients(inputs.tex_coord);
#ifdef _UE4BRDF
				col += pbrComputeSpecularUE4(vectors, specColor, roughness, specOcclusion);
#elif _REALTIME
				col += pbrComputeSpecularRealTime(vectors, specColor, roughness, specOcclusion);
#else
				col += pbrComputeSpecular(vectors, specColor, roughness, specOcclusion);
#endif
				 //------------------------------------------------------------
				 //					Debug
				 //------------------------------------------------------------
				//return baseColor.rgbb;
				//return roughness;
				//return sRGB2linear(getRoughness(roughness_tex, inputs.tex_coord));
				//return metallic;
				//return specularLevel;
				//return diffColor.rgbb;
				//return specColor.rgbb;
				//return inputs.tangent.rgbb;
				//return inputs.bitangent.rgbb;
				//return inputs.normal.rgbb;
				//return vectors.normal.rgbb;
				//return envSampleLOD(-reflect(vectors.eye, vectors.normal), 0).rgbb;

				return float4(col, 1);
			}

			void shadeShadow(V2F inputs)
			{
			}

			half4 frag (V2F i, float cullFace : VFACE) : SV_Target
			{
				half4 col = shade(i, cullFace);
				shadeShadow(i);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}

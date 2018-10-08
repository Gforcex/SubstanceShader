float3x3 GetTangentBasis(float3 TangentZ)
{
	float3 UpVector = abs(TangentZ.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
	float3 TangentX = normalize(cross(UpVector, TangentZ));
	float3 TangentY = cross(TangentZ, TangentX);
	return float3x3(TangentX, TangentY, TangentZ);
}

float3 TangentToWorld(float3 Vec, float3 TangentZ)
{
	return mul(Vec, GetTangentBasis(TangentZ));
}

half ComputeCubemapMipFromRoughness(half Roughness)
{
	half MipCount = maxLod;
	// Level starting from 1x1 mip
	half Level = 1 - 1.15 * log2(Roughness);//3 - 1.15 * log2(Roughness);
	return MipCount - 1 - Level;
}

float4 ImportanceSampleGGX(float2 E, float a2)
{
	float Phi = 2 * UNITY_PI * E.x;
	float CosTheta = sqrt((1 - E.y) / (1 + (a2 - 1) * E.y));
	float SinTheta = sqrt(1 - CosTheta * CosTheta);

	float3 H;
	H.x = SinTheta * cos(Phi);
	H.y = SinTheta * sin(Phi);
	H.z = CosTheta;

	float d = (CosTheta * a2 - CosTheta) * CosTheta + 1;
	float D = a2 / (UNITY_PI*d*d);
	float PDF = D * CosTheta;

	return float4(H, PDF);
}

float4 CosineSampleHemisphere(float2 E)
{
	float Phi = 2 * UNITY_PI * E.x;
	float CosTheta = sqrt(E.y);
	float SinTheta = sqrt(1 - CosTheta * CosTheta);

	float3 H;
	H.x = SinTheta * cos(Phi);
	H.y = SinTheta * sin(Phi);
	H.z = CosTheta;

	float PDF = CosTheta * (1 / UNITY_PI);

	return float4(H, PDF);
}
// Appoximation of joint Smith term for GGX
// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointApprox(float a2, float NoV, float NoL)
{
	float a = sqrt(a2);
	float Vis_SmithV = NoL * (NoV * (1 - a) + a);
	float Vis_SmithL = NoV * (NoL * (1 - a) + a);
	return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}

half3 ApproximateEnvBRDF(
	half3 f0,
	half roughness,
	half NdotV)
{
	half3 envBrdf;

	// Brian Karis' modification of Dimitar Lazarov's Environment BRDF.
	// cf https://www.unrealengine.com/blog/physically-based-shading-on-mobile
	const half4 c0 = half4(-1.0h, -0.0275h, -0.572h, 0.022h);
	const half4 c1 = half4(1.0h, 0.0425h, 1.04h, -0.04h);
	half4 r = roughness * c0 + c1;
	half a004 = min(r.x * r.x, exp2(-9.28h * NdotV)) * r.x + r.y;
	half2 AB = half2(-1.04h, 1.04h) * a004 + r.zw;
	envBrdf = f0 * AB.x + AB.yyy;

	return envBrdf;
}

sampler2D PreIntegratedGF; //RGFloat
half3 EnvBRDF(half3 SpecularColor, half Roughness, half NoV)
{
	// Importance sampled preintegrated G * F
	float2 AB = tex2D(PreIntegratedGF, float2(NoV, Roughness)).rg;

	// Anything less than 2% is physically impossible and is instead considered to be shadowing 
	float3 GF = SpecularColor * AB.x + saturate(50.0 * SpecularColor.g) * AB.y;
	return GF;
}

float Pow4(float x)
{
	return (x*x)*(x*x);
}

float3 PrefilterEnvMap(samplerCUBE AmbientCubemap, uint2 Random, float Roughness, float3 R, LocalVectors vectors, float lod)
{
	float3 FilteredColor = 0;
	float Weight = 0;

	const int NumSamples = 64;
	for (int i = 0; i < NumSamples; i++)
	{
		float2 E = Hammersley(i, NumSamples, Random);

		Roughness = Pow4(Roughness);
		//float3 H = importanceSampleGGX(E, vectors.tangent, vectors.bitangent, vectors.normal, Roughness);
		float3 H = TangentToWorld(ImportanceSampleGGX(E, Pow4(Roughness)).xyz, R);
		float3 L = 2 * dot(R, H) * H - R;

		float NoL = saturate(dot(R, L));
		if (NoL > 0)
		{
			FilteredColor += texCUBElod(AmbientCubemap, float4(L, lod) ).rgb * NoL;
			Weight += NoL;
		}
	}

	return FilteredColor / max(Weight, 0.001);
}

float3 IntegrateBRDF(uint2 Random, float Roughness, float NoV)
{
	float3 V;
	V.x = sqrt(1.0f - NoV * NoV);	// sin
	V.y = 0;
	V.z = NoV;						// cos

	float A = 0;
	float B = 0;
	float C = 0;

	const int NumSamples = 64;
	[unroll(64)]
	for (int i = 0; i < NumSamples; i++)
	{
		float2 E = Hammersley(i, NumSamples, Random);

		{
			float3 H = ImportanceSampleGGX(E, Pow4(Roughness)).xyz;
			float3 L = 2 * dot(V, H) * H - V;

			float NoL = saturate(L.z);
			float NoH = saturate(H.z);
			float VoH = saturate(dot(V, H));

			if (NoL > 0)
			{
				float a = Roughness* Roughness;
				float a2 = a * a;
				float Vis = Vis_SmithJointApprox(a2, NoV, NoL);
				float Vis_SmithV = NoL * sqrt(NoV * (NoV - NoV * a2) + a2);
				float Vis_SmithL = NoV * sqrt(NoL * (NoL - NoL * a2) + a2);
				//float Vis = 0.5 * rcp( Vis_SmithV + Vis_SmithL );

				// Incident light = NoL
				// pdf = D * NoH / (4 * VoH)
				// NoL * Vis / pdf
				float NoL_Vis_PDF = NoL * Vis * (4 * VoH / NoH);

				float Fc = pow(1 - VoH, 5);
				A += (1 - Fc) * NoL_Vis_PDF;
				B += Fc * NoL_Vis_PDF;
			}
		}

		{
			//float3 L = CosineSampleHemisphere(E).xyz;
			//float3 H = normalize(V + L);
			//
			//float NoL = saturate(L.z);
			//float NoH = saturate(H.z);
			//float VoH = saturate(dot(V, H));
			//
			//float FD90 = (0.5 + 2 * VoH * VoH) * Roughness;
			//float FdV = 1 + (FD90 - 1) * pow(1 - NoV, 5);
			//float FdL = 1 + (FD90 - 1) * pow(1 - NoL, 5);
			//C += FdV * FdL * (1 - 0.3333 * Roughness);
		}
	}

	return float3(A, B, C) / NumSamples;
}

float3 ApproximateSpecularIBL(samplerCUBE AmbientCubemap, float3 SpecularColor, float Roughness, float3 N, float3 V, LocalVectors vectors)
{
	float Mip = ComputeCubemapMipFromRoughness(Roughness);

	uint2 Random = InitRandom(V.xy * 0.5 + 0.5);

	// Function replaced with prefiltered environment map sample
	float3 R = 2 * dot(V, N) * N - V;
	float3 PrefilteredColor = PrefilterEnvMap(AmbientCubemap, Random, Roughness, R, vectors, Mip);

	float NoV = saturate(dot(N, V));
#if 1
	// Function replaced with 2D texture sample
	float2 AB = IntegrateBRDF(Random, Roughness, NoV).xy;

	return PrefilteredColor * (SpecularColor * AB.x + AB.y);
#else
	return PrefilteredColor * ApproximateEnvBRDF(SpecularColor, Roughness, NoV);
#endif
}


float3 SpecularIBL(samplerCUBE AmbientCubemap, float3 SpecularColor, float Roughness, float3 N, float3 V,float3 R, LocalVectors vectors)
{
	float Mip = ComputeCubemapMipFromRoughness(Roughness);
	float3 IBL = texCUBE(AmbientCubemap, float4(R, Mip)).rgb;

	float NoV = dot(N, V);

	return IBL * EnvBRDF(SpecularColor, Roughness, NoV);
	return IBL * ApproximateEnvBRDF(SpecularColor, Roughness, NoV);
	return ApproximateSpecularIBL(AmbientCubemap, SpecularColor, Roughness, N, V, vectors);
}

float3 _LightColor0;
float3 pbrComputeSpecularRealTime(LocalVectors vectors, float3 specColor, float roughness, float occlusion)
{
	float3 radiance = 0;
	float ndv = dot(vectors.eye, vectors.normal);

	float3 L = normalize(_WorldSpaceLightPos0.xyz);
	float3 Hn = normalize(L + vectors.eye);
	float3 Ln = -reflect(vectors.eye, vectors.normal);

	float fade = horizonFading(dot(vectors.vertexNormal, Ln), horizonFade);

	float ndl = dot(vectors.normal, Ln);
	ndl = max(1e-8, ndl);
	float vdh = max(1e-8, dot(vectors.eye, Hn));
	float ndh = max(1e-8, dot(vectors.normal, Hn));

	float lodS = computeLOD3(roughness);

	//no GGX Convolve Envmap
	radiance = fade * envSampleLOD(Ln, lodS) *
		cook_torrance_contrib(vdh, ndh, ndl, ndv, specColor, roughness) * 
		_LightColor0;

	return radiance * occlusion;
}

float3 pbrComputeSpecularUE4(LocalVectors vectors, float3 specColor, float roughness, float occlusion)
{
	float3 radiance = 0;
	float ndv = dot(vectors.eye, vectors.normal);

	float3 L = normalize(_WorldSpaceLightPos0.xyz);
	float3 Hn = normalize(L + vectors.eye);
	float3 Ln = -reflect(vectors.eye, vectors.normal);

	float fade = horizonFading(dot(vectors.vertexNormal, Ln), horizonFade);

	float ndl = dot(vectors.normal, Ln);
	ndl = max(1e-8, ndl);
	float vdh = max(1e-8, dot(vectors.eye, Hn));
	float ndh = max(1e-8, dot(vectors.normal, Hn));

	//radiance +=  cook_torrance_contrib(vdh, ndh, ndl, ndv, specColor, roughness) * _LightColor0;
	radiance += fade * ApproximateSpecularIBL(environment_texture_cube, specColor, roughness, vectors.normal, vectors.eye, vectors);
	//radiance *= ApproximateSpecularIBL(environment_texture_cube, specColor, roughness, vectors.normal, vectors.eye, vectors);

	return radiance * occlusion;
}

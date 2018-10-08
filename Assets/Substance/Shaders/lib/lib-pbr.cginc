
#include "lib-vectors.cginc"
#include "lib-env.cginc"
#include "lib-random.cginc"
#include "lib-emissive.cginc"
#include "Hammersley.cginc"

//: param auto environment_max_lod
uniform float maxLod;


//: param custom {
//:   "default": 16,
//:   "label": "Quality",
//:   "widget": "combobox",
//:   "values": {
//:     "Very low (4 spp)": 4,
//:     "Low (16 spp)": 16,
//:     "Medium (32 spp)": 32,
//:     "High (64 spp)": 64,
//:     "Very high (128 spp)": 128,
//:     "Ultra (256 spp)": 256
//:   },
//:   "group": "Common Parameters"
//: }
uniform int nbSamples;


//: param custom {
//:   "default": 1.3,
//:   "label": "Horizon Fading",
//:   "min": 0.0,
//:   "max": 2.0,
//:   "group": "Common Parameters"
//: }
uniform float horizonFade;



#define EPSILON_COEF  1e-4

float normal_distrib(
	float ndh,
	float Roughness)
{
	// use GGX / Trowbridge-Reitz, same as Disney and Unreal 4
	// cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
	float alpha = Roughness * Roughness;
	float tmp = alpha / max(1e-8, (ndh*ndh*(alpha*alpha - 1.0) + 1.0));
	return tmp * tmp * M_INV_PI;
}

float3 fresnel(
	float vdh,
	float3 F0)
{
	// Schlick with Spherical Gaussian approximation
	// cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
	float sphg = pow(2.0, (-5.55473*vdh - 6.98316) * vdh);
	return F0 + (float3(1.0, 1.0, 1.0) - F0) * sphg;
}

float G1(
	float ndw, // w is either Ln or Vn
	float k)
{
	// One generic factor of the geometry function divided by ndw
	// NB : We should have k > 0
	return 1.0 / (ndw*(1.0 - k) + k);
}

float visibility(
	float ndl,
	float ndv,
	float Roughness)
{
	// Schlick with Smith-like choice of k
	// cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
	// visibility is a Cook-Torrance geometry function divided by (n.l)*(n.v)
	float k = max(Roughness * Roughness * 0.5, 1e-5);
	return G1(ndl, k)*G1(ndv, k);
}

float3 cook_torrance_contrib(
	float vdh,
	float ndh,
	float ndl,
	float ndv,
	float3 Ks,
	float Roughness)
{
	// This is the contribution when using importance sampling with the GGX based
	// sample distribution. This means ct_contrib = ct_brdf / ggx_probability
	return fresnel(vdh, Ks) * (visibility(ndl, ndv, Roughness) * vdh * ndl / ndh);
}

float3 importanceSampleGGX(float2 Xi, float3 T, float3 B, float3 N, float roughness)
{
	float a = roughness * roughness;
	float cosT = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0)*Xi.y));
	float sinT = sqrt(1.0 - cosT * cosT);
	float phi = 2.0*M_PI*Xi.x;
	return
		T * (sinT*cos(phi)) +
		B * (sinT*sin(phi)) +
		N * cosT;
}

float probabilityGGX(float ndh, float vdh, float Roughness)
{
	return normal_distrib(ndh, Roughness) * ndh / (4.0*vdh);
}

float distortion(float3 Wn)
{
	// Computes the inverse of the solid angle of the (differential) pixel in
	// the cube map pointed at by Wn
	float sinT = sqrt(1.0 - Wn.y*Wn.y);
	return sinT;
}

float computeLOD(float3 Ln, float p)
{
	return max(0.0, (maxLod - 1.5) - 0.5 * log2(float(nbSamples) * p * distortion(Ln)));
}
//
float computeLOD1(float3 Ln, float p)
{
	float resolution = 1024; // resolution of source cubemap (per face)
	//float saTexel = 4.0 * M_PI / (6.0 * resolution * resolution); // cubemap
	float saTexel = 4.0 * M_PI / (2.0 * resolution * resolution); //for Latlong map
	float saSample = 1.0 / (float(nbSamples) * p);
	return max(0.5 * log2(saSample / saTexel) + 1.0, 0.0);
	//return max(0.5 * log2(saSample / (saTexel * distortion(Ln))) + 1.0, 0.0);
}
//Marmoset Toolbag 3 
float computeLOD2(float3 Ln, float p, float gloss)
{
	float resolution = 256; 
	float lod =  (0.5 * log2((resolution*resolution) / float(nbSamples)) + 1.5 * gloss * gloss) - 0.5*log2(p);
	return max(0, lod );
}
//Unreal Engine 4
float computeLOD3(float roughness)
{
	half LevelFrom1x1 = 1 - 1.2 * log2(roughness);
	return maxLod - 1 - LevelFrom1x1;
}
//Unity3D
float computeLOD4(float roughness)
{
	roughness = roughness * (1.7 - 0.7 * roughness);
	return roughness * maxLod + 3;
}

//Horizon fading trick from http ://marmosetco.tumblr.com/post/81245981087
float horizonFading(float ndl, float horizonFade)
{
	float horiz = clamp(1.0 + horizonFade * ndl, 0.0, 1.0);
	return horiz * horiz;
}


//Compute the lambertian diffuse radiance to the viewer's eye
float3 pbrComputeDiffuse(float3 normal, float3 diffColor, float occlusion)
{
	return occlusion * envIrradiance(normal) * diffColor;
}


//Compute the microfacets specular reflection to the viewer's eye
float3 pbrComputeSpecular(LocalVectors vectors, float3 specColor, float roughness, float occlusion)
{
	float3 radiance = 0;
	float ndv = dot(vectors.eye, vectors.normal);

	for (int i = 0; i<nbSamples; ++i)
	{
		float2 Xi = fibonacci2D(i, nbSamples);

		float3 Hn = importanceSampleGGX(
			Xi, vectors.tangent, vectors.bitangent, vectors.normal, roughness);
		float3 Ln = -reflect(vectors.eye, Hn);

		float fade = horizonFading(dot(vectors.vertexNormal, Ln), horizonFade);

		float ndl = dot(vectors.normal, Ln);
		ndl = max(1e-8, ndl);
		float vdh = max(1e-8, dot(vectors.eye, Hn));
		float ndh = max(1e-8, dot(vectors.normal, Hn));
		float lodS = roughness < 0.01 ? 0.0 : computeLOD(Ln, probabilityGGX(ndh, vdh, roughness));

		//lodS = min(8, lodS);
		radiance += fade * envSampleLOD(Ln, lodS) *
			cook_torrance_contrib(vdh, ndh, ndl, ndv, specColor, roughness);
	}
	// Remove occlusions on shiny reflections
	radiance *= occlusion / float(nbSamples);

	return radiance;
}
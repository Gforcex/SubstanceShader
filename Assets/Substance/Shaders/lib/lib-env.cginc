
#include "lib-defines.cginc"

//: param auto texture_environment
uniform sampler2D environment_texture;
uniform samplerCUBE environment_texture_cube;
//: param auto environment_rotation
uniform float environment_rotation;
//: param auto environment_exposure
uniform float environment_exposure;
//: param auto environment_irrad_mat_red
uniform mat4 irrad_mat_red;
//: param auto environment_irrad_mat_green
uniform mat4 irrad_mat_green;
//: param auto environment_irrad_mat_blue
uniform mat4 irrad_mat_blue;

//Helper that allows one to sample environment.Rotation is taken into account.The environment map is a panoramic env map behind the scene, that's why there is extra computation from dir vector.
float3 envSampleLOD(float3 dir, float lod)
{
	// WORKAROUND: Intel GLSL compiler for HD5000 is bugged on OSX:
	// https://bugs.chromium.org/p/chromium/issues/detail?id=308366
	// It is necessary to replace atan(y, -x) by atan(y, -1.0 * x) to force
	// the second parameter to be interpreted as a float
	float2 pos = M_INV_PI * float2(atan2(-dir.z , (-1.0 * dir.x)), 2.0 * asin(dir.y));
	pos = 0.5 * pos + 0.5;
	pos.x += environment_rotation;
	return tex2Dlod(environment_texture, float4(pos,0, lod)).rgb * environment_exposure;

	//input: dir = v.vettex
	//dir = normalize(dir);
	//float2 pos = M_INV_PI * float2(atan2(dir.z, dir.x) * 0.5, acos(dir.y));
	//pos = float2(0.5, 1.0) - pos;
	//pos.x += environment_rotation;
	//return tex2Dlod(environment_texture, float4(pos, 0, lod)).rgb * environment_exposure;

	//return texCUBElod(environment_texture_cube, float4(dir, lod)).rgb * environment_exposure;
}

//Return the irradiance for a given direction.The computation is based on environment's spherical harmonics projection.
float3 envIrradiance(float3 dir)
{
	float rot = environment_rotation * M_2PI;
	float crot = cos(rot);
	float srot = sin(rot);
	float4 shDir = float4(dir.xzy, 1.0);
	shDir = float4(
		shDir.x * crot - shDir.y * srot,
		shDir.x * srot + shDir.y * crot,
		shDir.z,
		1.0);
	return max(0, float3(
		dot(shDir, mul(irrad_mat_red, shDir)),
		dot(shDir, mul(irrad_mat_green, shDir)),
		dot(shDir, mul(irrad_mat_blue, shDir))
		)) * environment_exposure;
}
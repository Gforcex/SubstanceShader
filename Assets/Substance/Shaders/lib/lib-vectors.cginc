
#include "lib-normal.cginc"

//: param auto is_2d_view
uniform bool is2DView;

//: param auto is_perspective_projection
uniform bool is_perspective;

//: param auto world_eye_position
uniform float3 camera_pos;

//: param auto world_camera_direction
uniform float3 camera_dir;

//: param auto facing
uniform int facing;

bool isBackFace(bool FrontFacing) {
	return facing == -1 || (facing == 0 && !FrontFacing);
}

float3 getEyeVec(float3 position) {
	return normalize(_WorldSpaceCameraPos - position);
	//return is_perspective ?
	//	normalize(camera_pos - position) :
	//	-camera_dir;
}

float3 tangentSpaceToWorldSpace(float3 vecTS, V2F inputs) {
	return normalize(
		vecTS.x * inputs.tangent +
		vecTS.y * inputs.bitangent +
		vecTS.z * inputs.normal);
}

float3 worldSpaceToTangentSpace(float3 vecWS, V2F inputs) {
	// Assume the transformation is orthogonal
	return normalize(mul(vecWS , float3x3(inputs.tangent, inputs.bitangent, inputs.normal)));
}

struct LocalVectors {
	float3 vertexNormal;
	float3 tangent, bitangent, normal, eye;
};

//Compute local frame from custom world space normal
LocalVectors computeLocalFrame(V2F inputs, float3 normal, float cullFace) {
	LocalVectors vectors;
	vectors.vertexNormal = inputs.normal;
	vectors.normal = normal;

	//Double - sided normal if back faces are visible
	if (isBackFace(cullFace > 0)) {
		vectors.vertexNormal = -vectors.vertexNormal;
		vectors.normal = -vectors.normal;
	}

	vectors.eye = is2DView ?
		vectors.normal : // In 2D view, put view vector along the normal
		getEyeVec(inputs.position);

	//Trick to remove black artefacts Backface ? place the eye at the opposite - removes black zones
	if (dot(vectors.eye, vectors.normal) < 0.0) {
		vectors.eye = reflect(vectors.eye, vectors.normal);
	}

	//Create a local basis for BRDF work
	vectors.tangent = normalize(
		inputs.tangent
		- vectors.normal * dot(inputs.tangent, vectors.normal)
	);
	vectors.bitangent = normalize(
		inputs.bitangent
		- vectors.normal * dot(inputs.bitangent, vectors.normal)
		- vectors.tangent * dot(inputs.bitangent, vectors.tangent)
	);

	return vectors;
}


//Compute local frame from mesh and document height and normals
LocalVectors computeLocalFrame(V2F inputs, float cullFace) {

	//Get world space normal
	float3 normal = computeWSNormal(inputs.tex_coord, inputs.tangent, inputs.bitangent, inputs.normal);
	return computeLocalFrame(inputs, normal, cullFace);
}
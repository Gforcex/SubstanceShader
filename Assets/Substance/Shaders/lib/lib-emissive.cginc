//: param auto channel_emissive
uniform sampler2D emissive_tex;

//: param custom {
//:   "default": 1.0,
//:   "label": "Emissive Intensity",
//:   "min": 0.0,
//:   "max": 100.0,
//:   "group": "Common Parameters"
//: }
uniform float emissive_intensity;

//Compute the emissive radiance to the viewer's eye
vec3 pbrComputeEmissive(sampler2D emissive_tex, vec2 tex_coord)
{
	return emissive_intensity * texture(emissive_tex, tex_coord).rgb;
}
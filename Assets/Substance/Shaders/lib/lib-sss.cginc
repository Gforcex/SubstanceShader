
//: param auto channel_scattering
uniform sampler2D sss_tex;

//: param auto scene_original_radius
uniform float sssSceneScale;

//: param custom {
//:   "label": "Enable",
//:   "default": true,
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Enable the Subsurface Scattering. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform bool sssEnabled;

//Select whether the light penetrates straight through the material(translucent) or is diffused before starting to scatter(skin).
//: param custom {
//:   "default": 1,
//:   "label": "Scattering Type",
//:   "widget": "combobox",
//:   "values": {
//:     "Translucent": 0,
//:     "Skin": 1
//:   },
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Skin or Translucent/Generic. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform int sssType;

//Global scale to the subsurface scattering effect
//: param custom {
//:   "default": 0.5,
//:   "label": "Scale",
//:   "min": 0.01,
//:   "max": 1.0,
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Controls the radius/depth of the light absorption in the material. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform float sssScale;


//Wavelength dependency of the SSS of the material
//: param custom {
//:   "default": [0.701, 0.301, 0.305],
//:   "label": "Color",
//:   "widget": "color",
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>The color of light when absorbed by the material. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform vec3 sssColor;

//Return the material SSS coefficients
vec4 getSSSCoefficients(vec2 tex_coord) {
	if (sssEnabled) {
		vec3 sss = sssScale / sssSceneScale * getScattering(sss_tex, tex_coord) * sssColor;
		return vec4(sss, (sss.x + sss.y + sss.z) == 0 ? 0.0 : 1.0);
	}
	return 0;
}
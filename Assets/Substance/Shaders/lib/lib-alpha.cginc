
#include "lib-sampler.cginc"
#include "lib-utils.cginc"

//: param auto channel_opacity
uniform sampler2D opacity_tex;

//: param custom {
//:   "default": 0.33,
//:   "label": "Alpha threshold",
//:   "min": 0.0,
//:   "max": 1.0,
//:   "group": "Common Parameters"
//: }
uniform float alpha_threshold;

//: param custom {
//:   "default": false,
//:   "label": "Alpha dithering",
//:   "group": "Common Parameters"
//: }
uniform bool alpha_dither;

void alphaKill(vec2 tex_coord)
{
	float alpha = getOpacity(opacity_tex, tex_coord);
	float threshold = alpha_dither ? getDitherThreshold(uvec2(gl_FragCoord.xy)) : alpha_threshold;

	if (alpha < threshold) discard;
}
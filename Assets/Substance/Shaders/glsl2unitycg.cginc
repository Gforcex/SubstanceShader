#ifndef __GLSL_2_UNITYCG_CGINC__
#define __GLSL_2_UNITYCG_CGINC__

#define vec2 float2
#define vec3 float3
#define vec4 float4
#define uvec2 int2
#define mat2 float2x2
#define mat3 float3x3
#define mat4 float4x4
#define mod fmod
#define mix lerp
//#define atan atan2
#define fract frac 
#define rcp(v) (1/v)
#define texture tex2D
#define texture2D tex2D
#define texture2DLod tex2Dlod
#define textureOffset(tex, coord, offset) (tex2D(tex, coord + tex##_TexelSize * offset))
#define iResolution _ScreenParams

#endif //__GLSL_2_UNITYCG_CGINC__
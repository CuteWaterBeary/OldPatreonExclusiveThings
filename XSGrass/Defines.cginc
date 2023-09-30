sampler2D _WindTex; float4 _WindTex_ST;
sampler2D _MetallicGlossMap;
sampler2D _BladeDetail;
sampler2D _NormalMap; float4 _NormalMap_ST;
float4 _Color;
float _Metallic;
float _Glossiness;
float _CubemapGloss;
float _BumpScale;
float _TessellationUniform;
int _TessellationMode;
float _Cutoff;
float _RenderDistanceFalloff;
float _DistanceScalingFalloff;

float4 _SpecularColor;
float4 _BottomColor;
float _Scale;
float _Height;
float _Width;
float _BendStrength;
float _HeightRandom;
float _WidthRandom;
float _WindSpeed;
float _WindStrength;
float _TessFar;
float _TessClose;

#define grayscaleVec float3(0.2125, 0.7154, 0.0721)
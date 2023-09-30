sampler2D _MainTex; float4 _MainTex_ST;
sampler2D _MetallicGlossMap;
sampler2D _BumpMap; float4 _BumpMap_ST;
sampler2D _EmissionMap;
sampler2D _BorderTexture;
float4 _Color;
float4 _EmissionColor;
float _Metallic;
float _Glossiness;
float _BumpScale;
float _CenterScale;

float _SpecularLMOcclusion;
float _SpecLMOcclusionAdjust;
float _TriplanarFalloff;
float _LMStrength;
float _RTLMStrength;
int _TextureSampleMode;
int _LightProbeMethod;
int _ShadingStyle;
int _Invert;
int _GeoMode;
float _ExplodeAmount;
float _CenterFalloff;
float _RainbowBrightness;
float _FalloffBrightness;
float _ScrollSpeed;

#define grayscaleVec float3(0.2125, 0.7154, 0.0721)
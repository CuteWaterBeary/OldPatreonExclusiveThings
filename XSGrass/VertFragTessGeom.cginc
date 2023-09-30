

//This file contains the vertex, fragment, and Geometry functions for both the ForwardBase and Forward Add pass.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define V2F_SHADOW_CASTER_NOPOS float3 vec : TEXCOORD0;
#define TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o,opos) o.vec = mul(unity_ObjectToWorld, pos).xyz - _LightPositionRange.xyz; opos = o.pos;
#else
#define V2F_SHADOW_CASTER_NOPOS
#define TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o,opos) \
        opos = UnityClipSpaceShadowCasterPos(pos, normal); \
        opos = UnityApplyLinearShadowBias(opos);
#endif

#if defined(USING_STEREO_MATRICES)
#define _WorldSpaceStereoCameraCenterPos lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5)
#else
#define _WorldSpaceStereoCameraCenterPos _WorldSpaceCameraPos
#endif

//HELPER JUNK

inline float Dither8x8Bayer( int x, int y )
{
	const float dither[ 64 ] = {
	1, 49, 13, 61,  4, 52, 16, 64,
	33, 17, 45, 29, 36, 20, 48, 32,
	9, 57,  5, 53, 12, 60,  8, 56,
	41, 25, 37, 21, 44, 28, 40, 24,
	3, 51, 15, 63,  2, 50, 14, 62,
	35, 19, 47, 31, 34, 18, 46, 30,
	11, 59,  7, 55, 10, 58,  6, 54,
	43, 27, 39, 23, 42, 26, 38, 22};
	int r = y * 8 + x;
	return dither[r] / 64;
}

half calcDither(half2 screenPos)
{
	half dither = Dither8x8Bayer(fmod(screenPos.x, 8), fmod(screenPos.y, 8));
	return dither;
}

float2 calcScreenUVs(float4 screenPos)
{
	float2 uv = screenPos / (screenPos.w + 0.0000000001); //0.0x1 Stops division by 0 warning in console.
	#if UNITY_SINGLE_PASS_STEREO
		uv.xy *= float2(_ScreenParams.x * 2, _ScreenParams.y);	
	#else
		uv.xy *= _ScreenParams.xy;
	#endif
	
	return uv;
}

#define HASHSCALE3 float3(.1031, .1030, .0973)
#define mod(x,y) (x-y*floor(x/y))
#define rot2(a) float2x2(cos(a+float4(0,33,11,0)))
#define K 19.19

#include "Tessellation.cginc"
float rand(float3 co)
{
	return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}

// Construct a rotation matrix that rotates around the provided axis, sourced from:
// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
float3x3 AngleAxis3x3(float angle, float3 axis)
{
    float c, s;
    sincos(angle, s, c);

    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return float3x3(
        t * x * x + c, t * x * y - s * z, t * x * z + s * y,
        t * x * y + s * z, t * y * y + c, t * y * z - s * x,
        t * x * z - s * y, t * y * z + s * x, t * z * z + c
        );
}

float3x3 rotX(float angle)
{
    float s, c;
    sincos(angle, s, c);

    return float3x3(
            1, 0, 0,
            0, c, -s,
            0, s, c
        );
}

float3x3 rotZ(float angle)
{
    float s, c;
    sincos(angle, s, c);

    return float3x3(
            c, -s, 0,
            s, c, 0,
            0, 0, 1
        );
}

float3x3 tangentToLocal(float3 normal, float4 tangent, float3 bitangent)
{
    float3x3 t2l = float3x3(
        tangent.x, bitangent.x, normal.x,
        tangent.y, bitangent.y, normal.y,
        tangent.z, bitangent.z, normal.z
    );

    return t2l;
}

//----

g2f GeometryOutput(float3 pos, float3 normal, float3 tangent, float3 bitangent, float2 uv, float2 uv2)
{
    g2f o = (g2f)0;
    o.pos = UnityObjectToClipPos(pos);
    o.uv = uv;
    //Only pass needed things through for shadow caster
    #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(XS_PASS_DEPTHPREPASS)
        o.uv2 = uv2;
        o.btn[2] = normal;
        o.btn[1] = tangent;
        o.btn[0] = bitangent;
        o.worldPos = mul(unity_ObjectToWorld, float4(pos, 1));
        o.screenPos = ComputeScreenPos(o.pos);
        UNITY_TRANSFER_SHADOW(o, o.uv);
    #elif defined(UNITY_PASS_SHADOWCASTER) && !defined(XS_PASS_DEPTHPREPASS)
        TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o, o.pos);
    #endif
    return o;
}

g2f GenerateVertex(float3 vPos, float width, float height, float forward, float2 uv, float2 uv2, float3x3 transformMatrix, float3 normal, float3 tangent, float3 bitangent)
{
    float3 tangentPoint = float3(width, forward, height);
    float3 localPosition = vPos + mul(transformMatrix, tangentPoint);
    return GeometryOutput(localPosition, normal, tangent, bitangent, uv, uv2);
}

// #define INSTANCES 1
// [instance(INSTANCES)]
[maxvertexcount(4)]
void geom(triangle vertexOutput v[3], /*uint InstanceID : SV_GSInstanceID,*/ inout TriangleStream<g2f> tristream)
{   
    float3 vPos = (v[0].vertex + v[1].vertex + v[2].vertex) * 0.33333;
    float3 vNormal = v[0].normal;
    float4 vTangent = v[0].tangent;
    float3 vBitangent = cross(vNormal, vTangent);

    float3 worldPos = mul(unity_ObjectToWorld, v[0].vertex);
    float3x3 tan2local = tangentToLocal(vNormal, vTangent, vBitangent);
    float3x3 randomRot = rotZ(rand(vPos) * UNITY_TWO_PI);
    float3x3 bendRot = rotX(rand(vPos.zzx) * _BendStrength * UNITY_PI * 0.5);

    float2 windTexture = tex2Dlod(_WindTex, float4(worldPos.xz * _WindTex_ST.xy + _WindTex_ST.zw + (_Time.y * _WindSpeed), 0, 3)).xy * _WindStrength;
    float3 wind = float3(windTexture.x, windTexture.y, 0);
    float3x3 windRot = AngleAxis3x3(UNITY_PI * windTexture , wind );
    
    float3x3 transformationMatrix; 
    transformationMatrix = mul( tan2local, randomRot); // apply random rotation
    transformationMatrix = mul( transformationMatrix, bendRot); // apply bend/trample rotations
    transformationMatrix = mul( transformationMatrix, windRot); // apply wind rotations
    
    float distanceScaling = distance(worldPos, _WorldSpaceCameraPos);
    float scale = _Scale * smoothstep(_TessFar, _TessFar * _DistanceScalingFalloff, distanceScaling);

    float height = rand(vPos.zzy) * _HeightRandom + _Height;
    height = max(0.001, height);
    height *= scale;
    float width = rand(vPos.xzy) * _WidthRandom + _Width;
    width *= scale;
    float forward = rand(vPos.yyz);
    forward *= scale;

    float3 normal = UnityObjectToWorldNormal(vNormal);
    
    float2 uv2 = (v[0].uv2 + v[1].uv2 + v[2].uv2) * 0.333333;

    tristream.Append(GenerateVertex(vPos, width, 0, forward, float2(0, 0), uv2, transformationMatrix, normal, vTangent, vBitangent));
    tristream.Append(GenerateVertex(vPos, -width, 0, forward, float2(1, 0), uv2, transformationMatrix, normal, vTangent, vBitangent));
    //
    tristream.Append(GenerateVertex(vPos, width, height, forward, float2(0, 1), uv2, transformationMatrix, normal, vTangent, vBitangent));
    tristream.Append(GenerateVertex(vPos, -width, height, forward, float2(1, 1), uv2, transformationMatrix, normal, vTangent, vBitangent));
}

fixed4 frag (g2f i) : SV_Target
{
    float4 detailTexture = tex2D(_BladeDetail, i.uv);
    clip(detailTexture.r - _Cutoff);

    #if defined(UNITY_PASS_SHADOWCASTER)
        SHADOW_CASTER_FRAGMENT(i);
    // #elif defined(XS_PASS_DEPTHPREPASS)
    //     float4 detailTexture = tex2D(_BladeDetail, i.uv);
    //     clip(detailTexture.r - _Cutoff);
    //     return float4(0,0,0,1);
    #else

        //LIGHTING PARAMS
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
        i.uv = saturate(i.uv);

        float3 lightDir = getLightDir(i.worldPos);
        float4 lightCol = _LightColor0;

        //DIFFUSE
        fixed4 diffuse = lerp(_BottomColor, _Color * detailTexture, i.uv.y);
        
        //NORMAL
        float4 normalMap = tex2D(_NormalMap, i.uv);
        float3 worldNormal = getNormal(normalMap, i.btn[0], i.btn[1], i.btn[2]);
        
        //LIGHTING VECTORS
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
        float3 halfVector = normalize(lightDir + viewDir);
        float3 reflViewDir = reflect(-viewDir, worldNormal);
        float3 reflLightDir = reflect(lightDir, worldNormal);
        
        //DOT PRODUCTS FOR LIGHTING
        float ndl = dot(lightDir, worldNormal);
        float vdn = abs(dot(viewDir, worldNormal));
        float rdv = saturate(dot(reflLightDir, float4(-viewDir, 0)));

        //LIGHTING
        float3 lighting = float3(0,0,0);
        
        #if defined(LIGHTMAP_ON)
            float3 indirectDiffuse = ShadeSH9(float4(worldNormal, 1));
            float3 directDiffuse = getLightmap(i.uv2);

        #else
            float3 indirectDiffuse = ShadeSH9(float4(worldNormal, 1));
            float3 directDiffuse = (ndl * 0.5 + 0.5) * attenuation * _LightColor0 + indirectDiffuse; // Half Lambert lighting model
        #endif
        
        float3 indirectSpecular = getIndirectSpecular(i.worldPos, diffuse, vdn, float4(0,0,0,1-_CubemapGloss), reflViewDir, indirectDiffuse, viewDir, directDiffuse);
        float3 directSpecular = getDirectSpecular(lightCol, diffuse, rdv, attenuation, i.uv, i.uv2, worldNormal, viewDir, directDiffuse) * _SpecularColor;

        lighting = diffuse * directDiffuse ;
        lighting += directSpecular * i.uv.y; 
        lighting += indirectSpecular * i.uv.y;

        float3 col = lerp(_BottomColor * directDiffuse, lighting, i.uv.y);
        
        //float alphaMask = tex2D(_AlphaMask, saturate(i.uv));
        return float4(col, 1);
        
    #endif
}
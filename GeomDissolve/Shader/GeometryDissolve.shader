Shader "Xiexe/Patreon/GeometryDissolve"
{
	Properties
	{
        [Header(MAIN)]
        [Enum(Standard Lit, 0, Toon Lit, 1)]_ShadingStyle("Shading Style", int) = 0
        //[Enum(Unity Default, 0, Non Linear, 1)]_LightProbeMethod("Light Probe Sampling", Int) = 0
        [Enum(UVs, 0, Triplanar World, 1, Triplanar Object, 2)]_TextureSampleMode("Texture Mode", Int) = 0
        [Enum(Off,0,Front,1,Back,2)] _Culling ("Culling Mode", Int) = 2
		_TriplanarFalloff("Triplanar Blend", Range(0.5,1)) = 1
		_MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)

        [Space(16)]
        [Header(NORMALS)]
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(-1,1)) = 1
        
        [Space(16)]
        [Header(METALLIC)]
        _MetallicGlossMap("Metallic Map", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _Glossiness("Smoothness", Range(0,1)) = 0

        [Space(16)]
        [Header(EMISSION)]
        _EmissionMap("Emission Map", 2D) = "black" {}
        [HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)

        [Space(16)]
        [Header(GEOMETRY SETTINGS)]
        [Enum(View Based, 0, Directional Static, 1, Directional Time, 2)]_GeoMode("Dissolve Mode", int) = 0
        _CenterScale("Center Scale / Progress", Float) = 1
        _CenterFalloff("Falloff", Range(0,1)) = 0
        _RainbowBrightness("Rainbow Brightness", Range(0,1)) = 1
        _ExplodeAmount("Explode Amount", Range(0,1)) = 0.25

        [Space(16)]
        [Header(SCROLLING EMISSION SETTINGS)]
        _BorderTexture("Falloff Texture", 2D) = "black" {}
        _FalloffBrightness("Falloff Brightness", Range(0,2)) = 1
        _ScrollSpeed("Scroll Speed", Float) = 0.5

        [Space(16)]
        [Header(LIGHTMAPPING HACKS)]
        _SpecularLMOcclusion("Specular Occlusion", Range(0,1)) = 0
        _SpecLMOcclusionAdjust("Spec Occlusion Sensitiviy", Range(0,1)) = 0.2
        _LMStrength("Lightmap Strength", Range(0,1)) = 1
        _RTLMStrength("Realtime Lightmap Strength", Range(0,1)) = 1
    }
	SubShader
	{
		Tags { "Queue"="AlphaTest" "DisableBatching"="True"}
        AlphaToMask On
        Cull [_Culling]
		Pass
		{
            Tags {"LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
            #pragma geometry geom
			#pragma fragment frag
            #pragma multi_compile_fwdbase 
            #define GEOMETRY

            #ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif
			
			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
			};

			struct v2g
			{
                float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                nointerpolation uint vertID : TEXCOORD5;
			};

            struct g2f
            {
                float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 btn[3] : TEXCOORD3; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD6;
                float3 objPos : TEXCOORD7;
                float3 objNormal : TEXCOORD8;
                float distanceFromOriginal : TEXCOORD9;
                float4 screenPos : TEXCOORD10;
                float4 color : TEXCOORD12;
                SHADOW_COORDS(11)
            };

            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "LightingBRDF.cginc"
			#include "VertFragGeom.cginc"
			
			ENDCG
		}

        Pass
		{
            Tags {"LightMode"="ForwardAdd"}
            Blend One One
            ZWrite Off
            
			CGPROGRAM
			#pragma vertex vert
            #pragma geometry geom
			#pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #define GEOMETRY

            #ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif
			
			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
			};

			struct v2g
			{
                float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                nointerpolation uint vertID : TEXCOORD5;
			};

            struct g2f
            {
                float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 btn[3] : TEXCOORD3; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD6;
                float3 objPos : TEXCOORD7;
                float3 objNormal : TEXCOORD8;
                float distanceFromOriginal : TEXCOORD9;
                float4 screenPos : TEXCOORD10;
                float4 color : TEXCOORD12;
                SHADOW_COORDS(11)
            };

			
            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "LightingBRDF.cginc"
			#include "VertFragGeom.cginc"
			
			ENDCG
		}

        // Pass
        // {
        //     Tags{"LightMode" = "ShadowCaster"} //Removed "DisableBatching" = "True". If issues arise re-add this.
        //     Cull Off
        //     CGPROGRAM
        //     #include "UnityCG.cginc" 
        //     #include "Lighting.cginc"
        //     #include "AutoLight.cginc"
        //     #pragma vertex vert
        //     #pragma fragment frag
        //     #pragma geometry geom
        //     #pragma multi_compile_shadowcaster
        //     #define GEOMETRY
            
        //     #ifndef UNITY_PASS_SHADOWCASTER
        //         #define UNITY_PASS_SHADOWCASTER
        //     #endif
            
        //     struct appdata
		// 	{
		// 		float4 vertex : POSITION;
		// 		float2 uv : TEXCOORD0;
        //         float3 normal : NORMAL;
        //         float3 tangent : TANGENT;
		// 	};

		// 	struct v2g
		// 	{
        //         float4 vertex : SV_POSITION;
		// 		float2 uv : TEXCOORD0;
        //         float3 normal : TEXCOORD1;
        //         float3 tangent : TEXCOORD2;
        //         float4 screenPos : TEXCOORD5;
		// 	};

        //     struct g2f
        //     {
        //         float4 pos : SV_POSITION;
		// 		float2 uv : TEXCOORD0;
        //     };

        //     #include "Defines.cginc"
        //     #include "VertFragGeom.cginc"
        //     ENDCG
        // }
	}
}

Shader "Xiexe/Patreon/Vertex_Rounding"
{
	Properties
	{
        [Header(ROUNDING)]
        //[Enum(World Space, 0, Screen Space, 1)]_RoundingSpace("Rounding Space", Int) = 1
        _Rounding("Vertex Rounding Amount", Float) = 500
        _TextureResolutionRounding("Texture Resolution", Float) = 100
        _ColorDepth("Color Depth", Int) = 64

        [Header(MAIN)]
        //[Enum(Unity Default, 0, Non Linear, 1)]_LightProbeMethod("Light Probe Sampling", Int) = 0
        //[Enum(UVs, 0, Triplanar World, 1, Triplanar Object, 2)]_TextureSampleMode("Texture Mode", Int) = 0
		//_TriplanarFalloff("Triplanar Blend", Range(0.5,1)) = 1
		
        [Enum(Off,0,Front,1,Back,2)] _Culling ("Culling Mode", Int) = 2
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        [Toggle(_)]_UseVertexColors("Use Vertex Colors", Int) = 0
        [Toggle(_)]_UseVertexLightmapping("Use Vertex Lightmapping", Int) = 1

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
        _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR]_EmissionColor("Emission", Color) = (0,0,0,1)

        [Space(16)]
        [Header(LIGHTMAPPING HACKS)]
        _SpecularLMOcclusion("Specular Occlusion", Range(0,1)) = 0
        _SpecLMOcclusionAdjust("Spec Occlusion Sensitiviy", Range(0,1)) = 0.2
        _LMStrength("Lightmap Strength", Range(0,1)) = 1
        _RTLMStrength("Realtime Lightmap Strength", Range(0,1)) = 1
    }
	SubShader
	{
		Tags { "Queue"="Geometry" }
        Cull [_Culling]
		Pass
		{
            Tags {"LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
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
				noperspective float2 uv : TEXCOORD0;
                noperspective float2 uv1 : TEXCOORD1;
                noperspective float2 uv2 : TEXCOORD2;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float3 color : COLOR;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				noperspective float2 uv : TEXCOORD0;
                noperspective float2 uv1 : TEXCOORD1;
                noperspective float2 uv2 : TEXCOORD2;
                float3 btn[3] : TEXCOORD3; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD6;
                float3 objPos : TEXCOORD7;
                float3 objNormal : TEXCOORD8;
                float3 color : COLOR;
                SHADOW_COORDS(9)
			};

            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
			#include "LightingBRDF.cginc"
            #include "VertFrag.cginc"
			
			ENDCG
		}

        Pass
		{
            Tags {"LightMode"="ForwardAdd"}
            Blend One One
            ZWrite Off
            
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            
            #ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif

			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
			struct appdata
			{
				float4 vertex : POSITION;
				noperspective float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float3 color : COLOR;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				noperspective float2 uv : TEXCOORD0;
                float3 btn[3] : TEXCOORD1; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD4;
                float3 objPos : TEXCOORD5;
                float3 objNormal : TEXCOORD6;
                float3 color : COLOR;
                SHADOW_COORDS(7)
			};

            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "LightingBRDF.cginc"
			#include "VertFrag.cginc"
			
			ENDCG
		}

        Pass
        {
            Tags{"LightMode" = "ShadowCaster"} //Removed "DisableBatching" = "True". If issues arise re-add this.
            Cull Off
            CGPROGRAM
            #include "UnityCG.cginc" 
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            
            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif
            
            struct appdata
			{
				float4 vertex : POSITION;
				noperspective float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                //float3 color : COLOR;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				noperspective float2 uv : TEXCOORD0;
                //float3 color : COLOR;
			};

            #include "Defines.cginc"
            #include "VertFrag.cginc"
            ENDCG
        }
	}
}

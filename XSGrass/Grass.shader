Shader "Xiexe/Patreon/XSGrass"
{
    Properties
    {
        _BladeDetail("Cutoff Texture", 2D) = "white" {}
        _Cutoff("Cutoff", Float) = 0.5
        _NormalMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Bump Scale", Range(-1,1)) = 1
        _WindTex("Wind Texture", 2D) = "green" {}

        [Space(16)]
        _Color ("Top Color", Color) = (1,1,1,1)
        _BottomColor("Bottom Color", Color) = (0,0,0,1)
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _Glossiness("Specular Smoothness", Range(0,1)) = 0.15
        _CubemapGloss("Environment Smoothness", Range(0,1)) = 0.3
        _Scale("Scale", Float) = 0.02
        _Height("Height", Float) = 1.8
        _HeightRandom("Height Random", Range(0,1)) = 1
        _Width("Width", Range(0, 1)) = 0.15
        _WidthRandom("Width Random", Range(0,1)) = 0.15
        _BendStrength("Bend", Range(0,1)) = 0.3
        _WindStrength("Wind Strength", Range(0,1)) = 1
        _WindSpeed("Wind Speed", Range(0,5)) = 0.1
    
        [Space(16)]
        [Header(GEOMETRY SETTINGS)]
        //[Enum(Uniform, 0, Edge Length, 1, Distance, 2)]_TessellationMode("Tessellation Mode", Int) = 1
        _TessellationUniform("Max Blades", Range(0,1)) = 0.3
        _TessFar("Max Render Distance", float) = 10
        _RenderDistanceFalloff("Render Distance Falloff", range(0,1)) = 0.8
        _DistanceScalingFalloff("Distance Scale Falloff", range(0,1)) = 0.25
    }

    SubShader 
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest" "DisableBatching"="True"}
        Cull Off
        
        // Pass 
        // {  
        //     AlphaToMask On
        //     ColorMask 0
        //     CGPROGRAM
        //     #include "UnityCG.cginc"
        //     #include "AutoLight.cginc"
        //     #include "Lighting.cginc"
        //     #pragma vertex vert
        //     #pragma hull hull
        //     #pragma domain domain
        //     #pragma geometry geom
        //     #pragma fragment frag
        //     #pragma multi_compile_fwdbase 

        //     #ifndef XS_PASS_DEPTHPREPASS
        //         #define XS_PASS_DEPTHPREPASS
        //     #endif

        //     #pragma target 4.6

        //     struct vertexInput {
        //         float4 vertex : POSITION;
        //         float2 uv : TEXCOORD0;
        //         float3 normal : NORMAL;
        //         float4 tangent : TANGENT;
        //         float4 color : COLOR;
        //         float2 uv2 : TEXCOORD1;
        //     };

        //     struct vertexOutput {
        //         float4 vertex : POSITION;
        //         float2 uv : TEXCOORD0;
        //         float3 normal : NORMAL;
        //         float4 tangent : TANGENT;
        //         float4 color : COLOR;
        //         float2 uv2 : TEXCOORD1;
        //     };

        //     struct g2f {
        //         float4 pos : SV_POSITION;
        //         float2 uv : TEXCOORD0;
        //     };
            
        //     #include "Defines.cginc"
        //     #include "LightingFunctions.cginc"
        //     #include "VertFragTessGeom.cginc"
        //     ENDCG
        // }

        Pass 
        {  
            Tags{"LightMode"="ForwardBase"} 
            AlphaToMask On
            //ZTest Equal
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_fwdbase 

            #ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif

            #pragma target 4.6

            struct vertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct vertexOutput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct g2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float3 btn[3] : TEXCOORD2;// 3, 4
                float4 worldPos : TEXCOORD5;
                float4 screenPos : TEXCOORD6;
                SHADOW_COORDS(7)
            };
            
            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "VertFragTessGeom.cginc"
            ENDCG
        }

        Pass 
        {  
            Tags{"LightMode"="ForwardAdd"} 
            Blend One One
            ZWrite Off
            //ZTest Equal
            AlphaToMask On
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows

            #ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif

            #pragma target 4.6

            struct vertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct vertexOutput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct g2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float3 btn[3] : TEXCOORD2;// 3, 4
                float4 worldPos : TEXCOORD5;
                float4 screenPos : TEXCOORD6;
                SHADOW_COORDS(7)
            };
            
            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "VertFragTessGeom.cginc"
            ENDCG
        }

        Pass 
        {  
            Tags{"LightMode"="ShadowCaster"} 
            CGPROGRAM
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma geometry geom
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            
            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif

            #pragma target 4.6

            struct vertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct vertexOutput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR;
                float2 uv2 : TEXCOORD1;

            };

            struct g2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
            #include "VertFragTessGeom.cginc"
            ENDCG
        }
    }
}

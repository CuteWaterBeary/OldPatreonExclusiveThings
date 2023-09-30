/*  Copyright (C) Xiexe - All Rights Reserved
    Unauthorized resditrubition of this file is strictly prohibited.
    - April 2019
*/

Shader "Xiexe/CyberGeometry/Dots"
{
        Properties
    {
        [Header(MAIN)]
        [Toggle(_)]_WorldSpaceUV("World Space MainTex", Int) = 0
        [Toggle(_)]_ScrollMainTex("Scroll Main Tex", Int) = 0
        _MainTex ("MainTex", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _Brightness ("Brightness", Float) = 2
        _SpeedMainTex ("Speed", Float) = 1
        _RimSize("Rim Falloff", Range(-1,1)) = 1
    
        [Space(8)]
        [Header(SECONDARY)]
        _ScrollTex("Scrolling Mask", 2D) = "white" {}
        [Toggle(_)]_WorldSpaceUV2("World Space Mask", Int) = 0
        _StaticMask("Static Mask", 2D) = "white" {}
        _Speed ("Speed", Float) = 1
        
        [Space(8)]
        [Header(GEOMETRY SETTINGS)]
        [IntRange]_DotAmnt("Fill Amount", Range(1, 16)) = 1 
        _DotOffset("Vert Offset", Float) = 0.1
        [Toggle(_)]_TextureOffset("ScrollMask Affects Offset", Int) = 0
    }
    SubShader
    {
        Tags {"Queue"="Transparent+5"}
        Blend One One
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #define Points

            #include "UnityCG.cginc"
        
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2g
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
                nointerpolation uint vertID : TEXCOORD3;
            };

            struct g2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            #include "CyberGeo.cginc"
            ENDCG
        }
    }
}

/*  Copyright (C) Xiexe - All Rights Reserved
    Unauthorized resditrubition of this file is strictly prohibited.
    - June 2019
*/
Shader "Xiexe/Constellation"
{
    Properties
    {
        [Header(MAIN)]
        _MainTex("Albedo Texture", 2D) = "white" {}
        [HDR]_Color("Wire Color", Color) = (1,1,1,1)
        [HDR]_Color2("Sprites Color", Color) = (1,1,1,1)
        _LineAlbedo("Lines Use Albedo", Range(0,1)) = 1
        _DotsAlbedo("Sprites Use Albedo", Range(0,1)) = 0

        [Space(16)]
        [Header(SCROLLING)]
        _ScrollingTex("Scrolling Pattern", 2D) = "white" {}
        _LineScrolling("Lines Use Scrolling", Range(0,1)) = 1
        _DotsScrolling("Sprites Use Scrolling", Range(0,1)) = 1
        _ScrollSpeed("Scroll Speed", Float) = 0.5
        [Toggle(_)]_JitterScroll("Jitter Scroll", Int) = 1
        
        [Space(16)]
        [Header(SPRITESHEET)]
        _StarTexture("Sprite Sheet", 2D) = "white" {}
        _SheetCol("Sheet Colums", Int) = 2
        _SheetRow("Sheet Rows", Int) = 2
        _TotalFrames("Total Frames", Float) = 0
        _AnimationSpeed("Animation Speed", Float) = 0
        _RotationSpeed("Rotation Speed", Float) = 0
        
        [Space(16)]
        [Header(SPRITE SETTINGS)]
        _TriangleScale("Sprite Scale", Range(0,1)) = 0.2
        _ScaleJitter("Scale Randomness", Range(0,1)) = 1
        _StarTravelSpeed("Sprite Travel Speed", Float) = 3
        _StarCycleSpeed("Sprite Cycle Speed", Float) = 10
        [Toggle(_)]_SizeAnim("Animate Size", Int) = 1
        [Toggle(_)]_CycleStars("Cycle Sprites", Int) = 1
        _SpriteScaleBack("Sprite Scale Back", Range(0,1)) = 0.8

        [Space(16)]
        [Header(LINES)]
        _WireThickness("Wire Thickness", Range(0,1)) = 0.03
        [Toggle(_)]_CycleLines("Cycle Lines", Int) = 1
        _LineCycleSpeed("Line Cycle Speed", Float) = 10

    }
    SubShader
    {
        Tags {"Queue"="Transparent"}
        Blend One One
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

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
                float2 bary : TEXCOORD1; // distance to each edge of the triangle
                float isLine : TEXCOORD2;
                float4 color : TEXCOORD3;
                float2 uv1 : TEXCOORD4;
                float3 worldPos : TEXCOORD5;
            };

            #include "ConstellationCG.cginc"
            ENDCG
        }
    }
}

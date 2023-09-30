/*  Copyright (C) Xiexe - All Rights Reserved
    Unauthorized resditrubition of this file is strictly prohibited.
    - April 2019
*/

Shader "Xiexe/Minecraft/Particle"
{
     Properties
    {
        [Header(MAIN SETTINGS)]
        _MainTex ("Texture Sheet", 2D) = "white" {}
        _DestroyTex("Destroy Tex Sheet", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _Brightness ("Brightness", Float) = 2

        [Space(8)]
        [Header(GEOMETRY SETTINGS)]
        _Size("Size", Float) = 0.1
        [ToggleUI]_Pulse("Pulse", Int) = 0
    }
    SubShader
    {
        AlphaToMask On
        Pass
        {
            Tags {"Queue"="AlphaTest" "LightMode"="ForwardBase" "DisableBatching"="true"}
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
           
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2g
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
                nointerpolation uint vertID : TEXCOORD3;
                float4 color : TEXCOORD4;
            };

            struct g2f
            {
                float4 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float4 color : TEXCOORD4;
            };

            #include "MCGeo.cginc"
            ENDCG
        }
    }
}

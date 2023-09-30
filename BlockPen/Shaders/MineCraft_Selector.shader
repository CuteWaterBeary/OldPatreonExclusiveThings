/*  Copyright (C) Xiexe - All Rights Reserved
    Unauthorized resditrubition of this file is strictly prohibited.
    - April 2019
*/

Shader "Xiexe/Minecraft/Selector"
{
     Properties
    {
        [Header(MAIN SETTINGS)]
        _MainTex ("Selector Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _InteriorColor("Interior Grid Color", Color) = (1,1,1,1)
        _Brightness ("Brightness", Float) = 2

        [Space(8)]
        [Header(GEOMETRY SETTINGS)]
        _Size("Size", Float) = 0.1
        [ToggleUI]_Pulse("Pulse", Int) = 0
    }
    SubShader
    {
        Cull Off
        Pass
        {
            Tags {"Queue"="AlphaTest" "LightMode"="ForwardBase" "DisableBatching"="true"}
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #define VoxelSelector

            #include "UnityCG.cginc"
            // #include "AutoLight.cginc"
            // #include "Lighting.cginc"
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
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float4 color : TEXCOORD3;
                float4 colorTint : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
            };

            #include "MCGeo.cginc"
            ENDCG
        }
    }
}

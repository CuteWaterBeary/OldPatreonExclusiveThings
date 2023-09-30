Shader "Xiexe/Patreon/Hologram"
{
    Properties
    {
        [Header(SCAN LINES)]
        [HDR]_Color("Scanline Color", Color) = (1,1,1,1)
        _ColorInversion("Color Inversion", range(0,1)) = 0
        _VerticalLines("Vertical Line Count", Range(0,100)) = 60
        _Speed("Scan Speed", float) = 0.5
        _LineRotation("Line Rotation", float) = 0
        
        [Header(MAIN COLOR)]
        [HDR]_Color2("Rim Color", Color) = (1.5,1.5,1.5,0)
        [Toggle(_)]_InvertRim("Invert Rim", Int) = 0
        _RimRange("Rim Range", Range(0,1)) = 0.19

        [Header(EDGE LIGHTING)]
        [HDR]_EdgeLightColor("Edge Light Color", Color) = (1,1,1,1)
        _EdgeFade("Edge Light Range", Range(0,1)) = 0.6

        [Header(GLITCH)]
        _GlitchIntensity("Glitch Intensity", Float) = 0.001
        _GlitchSpeed("Glitch Speed", Float) = 6
        _GlitchSize("Glitch Size", Float) = 20

        [Header(DISTORTION)]
        _DistortionFrequency("Distortion Frequency", Range(0,100)) = 100
        _DistortionIntensity("Distortion Intensity", float) = 0.1
        _DistortionSpeed("Distortion Speed", float) = 50
    }
    SubShader
    {
        Tags{"Queue"="Transparent"}
        CGINCLUDE
            float _GlitchIntensity;
            float _GlitchSpeed;
            float _GlitchSize;

            float _DistortionFrequency;
            float _DistortionIntensity;
            float _DistortionSpeed;

            float rand(float n){return frac((n * (43758.5453123 - _Time.y)));}

            float4 vertexOffset(float4 vertex, float3 normal)
            {
                normal = normalize(normal);
                vertex.xyz += sin(_Time.y * _DistortionSpeed + vertex.y * normal * _DistortionFrequency) * (_DistortionIntensity * 0.01) ;
                vertex.xyz += _GlitchIntensity * (step(0.1, sin(_Time.y * 2 + vertex.y * _GlitchSize)) * step(0.99, sin(_Time.y*_GlitchSpeed * 0.5) )) * cos(_Time.y * 2 + vertex.y * 40) * rand(vertex.y) * normal;
                vertex.xyz -= _GlitchIntensity * (step(0.1, sin(_Time.y * 2 + vertex.y * _GlitchSize)) * step(0.99, sin(_Time.y*_GlitchSpeed * 0.5) )) * sin(_Time.y * 2 + vertex.y * 40) * rand(vertex.y) * normal;
                
                return vertex;
            }
        ENDCG

        //Depth prepass for two pass transparency
        Pass
        {
            ColorMask 0
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
            };

            v2f vert (appdata v)
            {
                v2f o;
                v.vertex = vertexOffset(v.vertex, v.normal);
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return 0;
            }

            ENDCG

        }

        Pass
        {
            Blend One One
            ZTest Equal
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 objPos : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float3 normal : TEXCOORD4;
                float distanceToObjectCenter : TEXCOORD5;
            };

            float _VerticalLines;
            float _Speed;
            float _RimRange;
            float4 _Color;
            float4 _Color2;
            float _LineRotation;
            int _InvertRim;
            float _EdgeFade;
            float4 _EdgeLightColor;
            float _ColorInversion;

            v2f vert (appdata v)
            {
                v2f o;
                v.vertex = vertexOffset(v.vertex, v.normal);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = mul(unity_ObjectToWorld, v.normal);
                o.uv = v.uv;
                o.objPos = v.vertex;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.screenPos = ComputeScreenPos(o.vertex);
                o.distanceToObjectCenter = distance( mul(unity_ObjectToWorld, float4(0,0,0,1)) , _WorldSpaceCameraPos);
                return o;
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

            float2 rotateUV(float2 uv, float rotation)
            {
                float mid = 0.5;
                return float2(
                    cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
                    cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
                );
            }

            half DotHalftone(float2 screenUV, half scalar) //Scalar can be anything from attenuation to a dot product
            {
                half2 uv = screenUV;
                #if UNITY_SINGLE_PASS_STEREO
                    uv *= 2;
                #endif
                
                half2 nearest = 2 * frac(100 * uv) - 1;
                half dist = length(nearest);
                half dotSize = 10 * scalar;
                half dotMask = step(dotSize, dist);

                return dotMask;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.normal = normalize(i.normal);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float vdn = saturate(dot(viewDir, i.normal));
                float omvdn = 1-vdn;

                float2 screenUV = (calcScreenUVs(i.screenPos) - 0.5) * i.distanceToObjectCenter + 0.5;
                screenUV = rotateUV(screenUV, _LineRotation*0.1);

                float rim = pow(lerp(omvdn, vdn, _InvertRim), _RimRange * 10);
                float edgelightMask = pow(omvdn, _EdgeFade * 10);
                float4 scanLines = saturate(sin((screenUV.y + (_Time.y*_Speed*100)) * (_VerticalLines*0.01))) * lerp(_Color, -_Color, _ColorInversion);
                scanLines += _Color2;
                scanLines *= rim;
                scanLines += lerp(0, _EdgeLightColor, edgelightMask);

                // float glitchMask = _GlitchIntensity * (step(0.1, sin(_Time.y * 30 + i.objPos.y * 20)) * step(0.99, sin(_Time.y*_GlitchSpeed * 0.5) ));
                // return glitchMask;

                return scanLines;
            }
            ENDCG
        }
    }
}
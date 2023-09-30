Shader "Xiexe/Patreon/Voronoi"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "black" {}
		_Mask("Voronoi Mask", 2D) = "white" {}
		_NoiseScale("Noise Scale", Float) = 10
		[HDR]_BorderColor("Border Color", Color) = (0,0,0,0)
		_BorderSharpness("Border Sharpness", Range(0,1)) = 1
		_BorderScale("Border Scale", Range(0,1)) = 0.01

		_Angle("Base Angle", Range(0,1)) = 1
		_Speed("Angle Speed", Float) = 0.5

		_Ramp("Emission Ramp", 2D) = "black" {}
		[HDR]_EmissionColor("Ramp Color Tint", Color) = (0,0,0,1)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase"}
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#ifndef UNITY_PASS_FORWARDBASE
				#define UNITY_PASS_FORWARDBASE
			#endif

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			#define gsVec float3(0.2125, 0.7154, 0.0721)

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float3 objPos : TEXCOORD2;
				float3 rootPos : TEXCOORD3;
			};

			float _NoiseScale;
			float _Speed;
			sampler2D _MainTex;
			sampler2D _Mask;
			float4 _EmissionColor;
			float _Angle;
			sampler2D _Ramp;
			float4 _BorderColor;
			float _BorderSharpness;
			float _BorderScale;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.objPos = v.vertex;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.rootPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				o.uv = v.uv;
				return o;
			}

			float2 N22(float2 p)
			{
				float3 a = frac(p.xyx*float3(123.34, 234.34, 345.65));
				a += dot(a, a+34.34);
				return frac(float2(a.x*a.y, a.y*a.z));
			}

			float3 N33(float3 p)
			{
				float3 a = frac(p.xyz*float3(123.34, 234.34, 345.65));
				a += dot(a, a+34.34);
				return frac(float3(a.x*a.y, a.y*a.z, a.x*a.z));
			}

			float3 mapToRampColor(float p, sampler2D tex)
			{
				float3 ramp = tex2Dlod(tex, float4(p, 0, 0, 0)).xyz;

				return ramp;
			}

			void voronoi3D(float3 pos, float3 scale, float angle, inout float3 cell, inout float3 border)
			{
				pos *= scale;
				float minDist = 3;

				float3 grid = frac(pos)-0.5;
				float3 currentCell = floor(pos);

				float3 oldOffsets;
				float3 oldCell;

				for (int y = -1; y <= 1; y++)
				{
					for(int x = -1; x <= 1; x++)
					{
						for(int z = -1; z <= 1; z++)
						{
							float3 offsets = float3(x,y,z);
							float3 n = N33(currentCell + offsets);
							float3 p = offsets + sin(n * angle) * 0.5;
							float3 c = grid - p;
							float d = dot(c,c);

							if(d<minDist)
							{
								minDist = d;
								oldCell = c;
								oldOffsets = offsets;
								cell = currentCell + offsets;
							}
						}
					}
				}
				//yxz = grb just to get rid of compiler warnings.
				minDist = 3;
				border = cell;
				for (int g = -1; g <= 1; g++)
				{
					for(int r = -1; r <= 1; r++)
					{
						for(int b = -1; b <= 1; b++)
						{
							float3 offsets = float3(g,r,b);
							float3 n = N33(currentCell + offsets);
							float3 p = offsets + sin(n * angle) * 0.5;
							float3 c = grid - p;
							float d = dot(0.5 * (oldCell+c), normalize(c-oldCell));

							border = min(border, d);
						}
					}
				}

			}

			// float4 voronoi2D(float2 pos, float scale, float angle)
			// {
			// 	pos *= scale;
			// 	float t = angle;//(_Time.y * speed) + 0.001;
			// 	float minDist = 3; //res
			// 	float2 cell = 0;

			// 	float2 grid = frac(pos) - 0.5;
			// 	float2 currentCell = floor(pos);

			// 	float2 oldOffsets;
			// 	float2 oldCell;

			// 	for (int y = -1; y<=1; y++)
			// 	{
			// 		for(int x = -1; x<=1; x++)
			// 		{
			// 			float2 offsets = float2(x,y);

			// 			float2 n = N22(currentCell + offsets);
			// 			float2 p = offsets + sin(n * t) * 0.5;
			// 			float2 c = grid - p;
			// 			float d = dot(c,c);

			// 			if(d<minDist)
			// 			{
			// 				minDist = d;
			// 				oldCell = c;
			// 				oldOffsets = offsets;
			// 				cell = currentCell + offsets;
			// 			}
			// 		}
			// 	}

			// 	minDist = 3;
			// 	float2 border = cell;
			// 	for (int y = -1; y<=1; y++)
			// 	{
			// 		for(int x = -1; x<=1; x++)
			// 		{
			// 			float2 offsets = float2(x,y);

			// 			float2 n = N22(currentCell + offsets);
			// 			float2 p = offsets + sin(n * t) * 0.5;
			// 			float2 c = grid - p;
			// 			float d = dot(0.5 * (oldCell+c), normalize(c-oldCell));

			// 			border = min(border, d);
			// 		}
			// 	}

			// 	return float4(cell, border);
			// }

			float4 frag (v2f i) : SV_Target
			{
				float4 col = float4(0,0,0,1);
				float4 mask = tex2D(_Mask, i.uv);
				float3 worldPos = i.worldPos - (i.rootPos * 0.8);
				
				worldPos = abs(worldPos);
				worldPos.y += 0.1;

				float3 cell = 0;
				float3 border = 0;
				voronoi3D(worldPos, _NoiseScale , (_Angle * 6) + (_Time.y * _Speed), cell, border);

				float3 ambient = ShadeSH9(float4(0,0,0,1));
				float3 emissionRamp = mapToRampColor(dot(N33(cell), gsVec), _Ramp) * mask;
				float3 diffuse = tex2D(_MainTex, i.uv).rgb ;
 				float fade = pow(1-i.objPos.z + 0.2, 3);

				float borderLerp = 1-saturate(smoothstep(_BorderScale - _BorderSharpness, _BorderScale + _BorderSharpness, border.y));
				col.rgb = lerp(diffuse, _EmissionColor * emissionRamp * (1-borderLerp) + lerp(0, _BorderColor.rgb, borderLerp), mask) * (_LightColor0 + ambient);

				return col;
			}
			ENDCG
		}
	}
}

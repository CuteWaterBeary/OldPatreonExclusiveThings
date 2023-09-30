Shader "Xiexe/Patreon/Slime"
{
	Properties
	{
		_MainTex ("Main Texture", 2D) = "white" {}
		_Color("Primary Color", Color) = (1,1,1,1)
		_Color2("Secondary Color", Color) = (1,1,1,1)
		_ColorFade("Color Transition", Range(0,6)) = 0.1
		_Translucency("Translucency", Range(0,1)) = 0.8
        _Distortion("Distortion", range(-1, 1)) = 1

		[Space(16)]
		[Header(NORMAL)]
		_NormalMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Normal Scale", Range(-1,1)) = 1
		_NormalScrollSpeed("Scroll Speed", Range(0,1)) = 0.1

		[Space(16)]
		[Header(SPECULAR)]
		_SpecularColor("Specular Color", Color) = (1,1,1,1)
		_SpecularSmoothness("Specular Smoothness", Range(0,1)) = 1
		_ReflectionProbIntensity("Reflectivity", Range(0,1)) = 0.5

		[Space(16)]
		[Header(MATCAPS)]
		_Matcap("Matcap(Additive)", 2D) = "black" {}
		[HDR]_MatcapColor("Matcap Color", Color) = (1,1,1,1)

		[Space(16)]
		[Header(RIMLIGHTING)]
		[HDR]_RimColor("Rim Color", Color) = (1,1,1,1)
		_RimSharpness("Rim Sharpness", Float) = 1
		_RimRange("Rim Range", Float) = 1
		_RimIntensity("Rim Intensity", Float) = 1
		_RimThreshold("Rim Threshold", Float) = 1

		[Space(16)]
		[Header(TRANSMISSION)]
		_SSColor ("Tansmission Color", Color) = (0,0,0,0)
        _SSDistortion("Normal Distortion", Range(0,3)) = 0.25
        _SSScale("Transmission Scale", Range(0,3)) = 1.5

		[Space(16)]
		[Header(SUBSURFACE SCATTERING)]
		[HDR]_SubsurfaceColor("Subsurface Color", color) = (0,0,0,1)
		_TuneCurvature("Tune Curvature", Range(0,1)) = 1

		[Space(16)]
		[Header(Blur)]
		_Blur("Blur", float) = 40
		[IntRange]_Samples("Samples", Range(0,6)) = 4

	}
	SubShader
	{
		Tags { "Queue"="AlphaTest+30" }
		GrabPass {"_GrabTexture"}
		Pass
		{
			Tags{"LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile_fwdbase
			
			#ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif

			#include "Lighting.cginc"
			ENDCG
		}
		Pass
		{
			Tags{"LightMode"="ForwardAdd"}
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#pragma multi_compile_fwdadd_fullshadows
			
			#ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif

			#include "Lighting.cginc"
			ENDCG
		}
		


	}
	Fallback "Diffuse"
}

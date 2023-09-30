	#include "UnityPBSLighting.cginc"
	#include "AutoLight.cginc"
	#include "UnityCG.cginc"

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : NORMAL;
		float3 tangent : TANGENT;
	};

	struct v2f
	{
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float3 normal : TEXCOORD1;
		float4 grabUV : TEXCOORD2;
		float4 worldPos : TEXCOORD3;
		float3 worldNormal : TEXCOORD4;
		float4 objectPos : TEXCOORD5;
		float3 tangent : TEXCOORD6;
		float3 bitangent : TEXCOORD7;
		SHADOW_COORDS(8)
	};


	sampler2D _GrabTexture;
	float4 _GrabTexture_TexelSize;

	sampler2D _NormalMap;
	float _BumpScale;
	float4 _NormalMap_ST;
	float _NormalScrollSpeed;

	sampler2D _DetailNormal;
	float _DetailNormalScale;
	float _DetailNormalSpeed;
	
	float4 _Color;
	float4 _Color2;
	float _Distortion;
	float _ColorPower;
	float _RimPower;
	float4 _RimColor;
	float _RimSharpness;
	float _RimRange;
	float _RimIntensity;
	float _RimThreshold;
	float4 _SpecularColor;
	float _SpecularSmoothness;

	float4 _SSColor;
	float _SSDistortion;
	float _SSPower;
	float _SSScale;
	float _ReflectionProbIntensity;
	float _TuneCurvature;
	float _ShadowBrightness;
	float4 _SubsurfaceColor;
	int _Samples;
	float _Blur;

	float _ColorFade;
	float _Translucency;

	sampler2D _Matcap;
	float4 _MatcapColor;

	sampler2D _MainTex;
	float4 _MainTex_ST;
	#define grayscaleVec float3(0.2125, 0.7154, 0.0721)

	v2f vert (appdata v)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		o.grabUV = ComputeScreenPos(o.pos);
		float3 worldNormal = UnityObjectToWorldNormal(v.normal);
		o.worldNormal = worldNormal;
		o.normal = v.normal;
		float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
		o.worldPos = worldPos;
		o.tangent = v.tangent;
		o.bitangent = cross(o.tangent, o.normal);
		
		UNITY_TRANSFER_SHADOW(o, o.uv);
		UNITY_TRANSFER_FOG(o,o.pos);
		return o;
	}

	inline half Dither8x8Bayer( int x, int y )
	{
		const half dither[ 64 ] = {
		1, 49, 13, 61,  4, 52, 16, 64,
		33, 17, 45, 29, 36, 20, 48, 32,
		9, 57,  5, 53, 12, 60,  8, 56,
		41, 25, 37, 21, 44, 28, 40, 24,
		3, 51, 15, 63,  2, 50, 14, 62,
		35, 19, 47, 31, 34, 18, 46, 30,
		11, 59,  7, 55, 10, 58,  6, 54,
		43, 27, 39, 23, 42, 26, 38, 22};
		int r = y * 8 + x;
		return dither[r] / 64;
	}

	half calcDither(half2 screenPos)
	{
		half dither = Dither8x8Bayer(fmod(screenPos.x, 8), fmod(screenPos.y, 8));
		return dither;
	}

	// // Support Functions for Blurring
	float rand(float2 co) {
		return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
	}

	float3 draw(float4 uv) {
		return tex2Dproj(_GrabTexture, uv).rgb;
	}

	float4 blur(float4 uv, float dist, float vdn, float dither)
	{	
		
		float bluramount = (float)(_Blur * 0.0001 * dither * (1-vdn) );
		float3 blurred_image = float3(0,0,0);
		float rstep = 6.283185307179586 / _Samples;

		if(_Samples > 0)
		{
			for (float ii = 0; ii < _Samples; ii++) 
			{
				float base_rot = ii * rstep;
				float rot = rstep + base_rot;
				float2 this_rot = float2(cos(rot), sin(rot));
				half2 q = this_rot;
				float4 uv2 = float4(uv.xy + (q * bluramount), uv.zw);
				blurred_image = blurred_image + draw(uv2) ;
			}
			blurred_image = blurred_image / _Samples;
		}
		else
		{
			blurred_image = draw(uv);
		}
		return float4(blurred_image, 1);
	}
	//-----
	
	half3 calcLightDir(float3 worldPos)
	{   
		half3 lightDir = UnityWorldSpaceLightDir(worldPos);

		half3 probeLightDir = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;
		lightDir = (lightDir + probeLightDir); //Make light dir the average of the probe direction and the light source direction.

		#if !defined(POINT) && !defined(SPOT) && !defined(VERTEXLIGHT_ON) // if the average length of the light probes is null, and we don't have a directional light in the scene, fall back to our fallback lightDir
			if(length(unity_SHAr.xyz*unity_SHAr.w + unity_SHAg.xyz*unity_SHAg.w + unity_SHAb.xyz*unity_SHAb.w) == 0 && length(lightDir) < 0.1)
			{
				lightDir = half4(1, 1, 1, 0);
			}
		#endif

		return normalize(lightDir);
	}
	void calcLightCol(bool lightEnv, inout half3 indirectDiffuse, inout half4 lightColor)
	{
		//If we're in an environment with a realtime light, then we should use the light color, and indirect color raw.
		//...
		if(lightEnv)
		{
			lightColor = _LightColor0;
			indirectDiffuse = indirectDiffuse;
		}
		else
		{
			lightColor = indirectDiffuse.xyzz * 0.5;    // ...Otherwise
			indirectDiffuse = indirectDiffuse * 0.5;    // Keep overall light to 100% - these should never go over 100%
														// ex. If we have indirect 100% as the light color and Indirect 50% as the indirect color, 
														// we end up with 150% of the light from the scene.
		}
	}

	half4 calcRimLight(float vdn, float ndl, half4 lightCol, half3 indirectDiffuse)
	{
		half rimIntensity = saturate(vdn) * pow((ndl*0.5+0.5), _RimThreshold);
		rimIntensity = smoothstep(_RimRange - _RimSharpness, _RimRange + _RimSharpness, rimIntensity);
		half4 rim = rimIntensity * _RimIntensity * (lightCol + indirectDiffuse.xyzz);
		return rim * _RimColor;
	}

	//Transmission - Based on a 2011 GDC Conference from by Colin Barre-Bresebois & Marc Bouchard
	//Modified by Xiexe
	half4 calcTransmission(float4 albedo, float ndl, half3 lightDir, half3 viewDir, half3 normal, half4 lightCol, half3 indirectDiffuse)
	{
		UNITY_BRANCH
		if(any(_SSColor.rgb)) // Skip all the SSS stuff if the color is 0.
		{
			//d.ndl = smoothstep(_SSSRange - _SSSSharpness, _SSSRange + _SSSSharpness, d.ndl);
			half attenuation = (ndl * 0.5 + 0.5);
			half3 H = normalize(lightDir + normal * _SSDistortion);
			half VdotH = pow(saturate(dot(-viewDir, -H)), 3);
			half3 I = _SSColor * (VdotH + indirectDiffuse) * attenuation * _SSScale;
			half4 SSS = half4(lightCol.rgb * I * albedo, 1);
			SSS = max(0, SSS); // Make sure it doesn't go NaN

			return SSS;
		}
		else
		{
			return 0;
		}
	}
	
	//Reflection direction, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
	half3 getReflectionUV(half3 direction, half3 position, half4 cubemapPosition, half3 boxMin, half3 boxMax) 
	{
		#if UNITY_SPECCUBE_BOX_PROJECTION
			if (cubemapPosition.w > 0) {
				half3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
				half scalar = min(min(factors.x, factors.y), factors.z);
				direction = direction * scalar + (position - cubemapPosition);
			}
		#endif
		return direction;
	}

	half3 calcIndirectSpecular(float4 worldPos, half4 smoothness, half3 reflDir)
	{
		half3 spec = half3(0,0,0);

		#if defined(UNITY_PASS_FORWARDBASE) //Indirect PBR specular should only happen in the forward base pass. Otherwise each extra light adds another indirect sample, which could mean you're getting too much light. 
			half3 reflectionUV1 = getReflectionUV(reflDir, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
			half4 probe0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionUV1, smoothness * UNITY_SPECCUBE_LOD_STEPS);
			half3 probe0sample = DecodeHDR(probe0, unity_SpecCube0_HDR);

			half3 indirectSpecular;
			half interpolator = unity_SpecCube0_BoxMin.w;
			
			UNITY_BRANCH
			if (interpolator < 0.99999) 
			{
				half3 reflectionUV2 = getReflectionUV(reflDir, worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
				half4 probe1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflectionUV2, smoothness * UNITY_SPECCUBE_LOD_STEPS);
				half3 probe1sample = DecodeHDR(probe1, unity_SpecCube1_HDR);
				indirectSpecular = lerp(probe1sample, probe0sample, interpolator);
			}
			else 
			{
				indirectSpecular = probe0sample;
			}
			spec = indirectSpecular;
		#endif
		return spec;
	}

	half2 matcapSample(half3 worldUp, half3 viewDirection, half3 normalDirection)
	{
		half3 worldViewUp = normalize(worldUp - viewDirection * dot(viewDirection, worldUp));
		half3 worldViewRight = normalize(cross(viewDirection, worldViewUp));
		half2 matcapUV = half2(dot(worldViewRight, normalDirection), dot(worldViewUp, normalDirection)) * 0.5 + 0.5;
		return matcapUV;				
	}

	half2 calcScreenUVs(half4 screenPos)
	{
		half2 uv = screenPos / (screenPos.w + 0.0000000001); //0.0x1 Stops division by 0 warning in console.
		#if UNITY_SINGLE_PASS_STEREO
			uv.xy *= half2(_ScreenParams.x * 2, _ScreenParams.y);	
		#else
			uv.xy *= _ScreenParams.xy;
		#endif
		
		return uv;
	}

	float3 saturation(float3 rgb, float adjustment)
	{
		// Algorithm from Chapter 16 of OpenGL Shading Language
		const float3 W = float3(0.2125, 0.7154, 0.0721);
		float3 intensity = dot(rgb, W);
		return lerp(intensity, rgb, adjustment);
	}

	void calcNormal(float4 normalMap, inout float3 normal, inout float3 tangent, inout float3 bitangent)
	{
		half3 nMap = UnpackScaleNormal(normalMap, _BumpScale);
		nMap.y *= _BumpScale;

		half3 tspace0 = half3(tangent.x, bitangent.x, normal.x);
		half3 tspace1 = half3(tangent.y, bitangent.y, normal.y);
		half3 tspace2 = half3(tangent.z, bitangent.z, normal.z);

		half3 calcedNormal;
		calcedNormal.x = dot(tspace0, nMap);
		calcedNormal.y = dot(tspace1, nMap);
		calcedNormal.z = dot(tspace2, nMap);
		
		calcedNormal = normalize(calcedNormal);
		half3 bumpedTangent = (cross(bitangent, calcedNormal));
		half3 bumpedBitangent = (cross(calcedNormal, bumpedTangent));

		normal = calcedNormal;
		tangent = bumpedTangent;
		bitangent = bumpedBitangent;
	}


	fixed4 frag (v2f i) : SV_Target
	{
		UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos.xyz);
		#if UNITY_SINGLE_PASS_STEREO
			float3 cameraPos = float3((unity_StereoWorldSpaceCameraPos[0]+ unity_StereoWorldSpaceCameraPos[1])*.5); 
		#else
			float3 cameraPos = _WorldSpaceCameraPos;
		#endif

		float4 normalMap = tex2D(_NormalMap, i.uv * _NormalMap_ST.xy + _NormalMap_ST.zw + (_Time.y * _NormalScrollSpeed));
		calcNormal(normalMap, i.normal, i.tangent, i.bitangent);

		float3 lightDir = calcLightDir(i.worldPos);
		bool lightEnv = any(_WorldSpaceLightPos0.xyz);

		float3 worldNormal = normalize(i.worldNormal);
		float3 normal = normalize(i.normal);
		float3 viewDirRaw = normalize(i.worldPos - _WorldSpaceCameraPos.xyz);
		float3 viewDir = normalize(i.worldPos - cameraPos.xyz);

		half3 halfVector = normalize(lightDir + viewDir);
		half3 reflLight = reflect(lightDir, worldNormal);
		half3 reflView = reflect(viewDir, worldNormal);

		float ndl = dot(worldNormal, lightDir);
		float vdn = 1-dot(worldNormal, -viewDir);
		float vdh = DotClamped(viewDir, halfVector);
		float ndh = DotClamped(worldNormal, halfVector);
		float rdv = saturate(dot(reflLight, float4(viewDir, 0)));
		float dist = 1 / distance(_WorldSpaceCameraPos, i.worldPos);

		float3 indirect = ShadeSH9(float4(0,1,0,1));
		float4 lightCol = _LightColor0;
		calcLightCol(lightEnv, indirect, lightCol);	

		float3 attenColored = atten + indirect;

		fixed4 col = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
		float2 screenUV = calcScreenUVs(i.grabUV);
		float dither = calcDither(screenUV);
		//return dither;

		#if UNITY_SINGLE_PASS_STEREO
			_Distortion *= 0.5;
		#endif
		
		half3 refracted = normal * abs(normal) * length(_GrabTexture_TexelSize.xy) * _Distortion * 255 * dist;
		i.grabUV.xy = refracted.xy * i.grabUV.w + i.grabUV.xy;      
		float4 refractCol = blur(i.grabUV, dist, vdn, dither);//tex2Dproj(_GrabTexture, i.grabUV);

		float3 rimLarge = lerp(0.1, 1, saturate(pow(1-vdn, 5)));
		float3 rimSmall = calcRimLight(vdn, ndl, lightCol, indirect);
		//return rimLarge.rgbb;

		_SpecularSmoothness *= 1.7 - 0.7 * _SpecularSmoothness;
		float3 directSpecular = saturate(pow(rdv, _SpecularSmoothness * 128)) * lightCol * _SpecularColor;
		float3 indirectSpecular = calcIndirectSpecular(i.worldPos, 1-_SpecularSmoothness , reflView) * _ReflectionProbIntensity;
		float4 transmission = calcTransmission(col * _Color, ndl, lightDir, viewDir, worldNormal, lightCol, indirect);

		float ndlSS = ndl * 0.5 + 0.5;
		float curvature = saturate( length(fwidth(worldNormal.xyz)) / (length(fwidth(i.worldPos.xyz)) * _TuneCurvature * 100) );
		curvature += (dither * 2);

		float3 diffusionColor = lerp(0, _SubsurfaceColor, saturate(curvature * curvature * 0.5 + 0.5)) * smoothstep(-0.6,0.1, ndl ) * atten;
		float leftToRightGradient = smoothstep(-0.5,0.5, ndl) * atten;
		float3 diffusion = lerp( leftToRightGradient, diffusionColor, smoothstep(-0.3,0.5,-ndl) + (1-atten) ) ;	
		//return diffusion.rgbb;
		
		float2 matcapUV = matcapSample(float3(0,1,0), viewDirRaw, worldNormal);
		float4 matcap = tex2D(_Matcap, matcapUV) * _MatcapColor;
		
		float4 slimeColor = lerp(_Color, _Color2, saturate(pow(1-vdn, _ColorFade))) * col;

		col *= lerp(slimeColor, refractCol, _Translucency); 
		//col.rgb *= rimLarge;
		col.rgb += rimSmall;
		col.rgb += directSpecular;
		col.rgb += indirectSpecular;
		col += matcap;
		col += transmission;
		col *= (diffusion.rgbb * lightCol) + lerp(indirect.rgbb * 3, indirect.rgbb, saturate(dot(grayscaleVec, indirect)));
		
		//col.rgb = lerp(saturation(col, 2), col, smoothstep(0,1,vdn) ).rgb;
		UNITY_APPLY_FOG(i.fogCoord, col);
		return col;
	}
	


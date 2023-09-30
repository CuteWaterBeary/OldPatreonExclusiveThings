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

//Since this is shared, and the output structs/input structs are all slightly differently named in each shader template, just handle them all here.
float4 CustomStandardLightingBRDF(
    #if defined(GEOMETRY)
        g2f i
    #elif defined(TESSELLATION)
        vertexOutput i
    #else
        v2f i
    #endif
    )
{
    //LIGHTING PARAMS
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
    float3 lightDir = getLightDir(i.worldPos);
    float4 lightCol = _LightColor0;

    //NORMAL
    float3 normalMap = texTPNorm(_BumpMap, _BumpMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);
    float3 worldNormal = getNormal(normalMap, i.btn[0], i.btn[1], i.btn[2]);

    //METALLIC SMOOTHNESS
    float4 metallicGlossMap = texTP(_MetallicGlossMap, _MainTex_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);
    float4 metallicSmoothness = getMetallicSmoothness(metallicGlossMap);

    //DIFFUSE
    fixed4 diffuse = texTP(_MainTex, _MainTex_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv) * _Color;
    fixed4 diffuseColor = diffuse; //Store for later use, we alter it after.
    diffuse.rgb *= (1-metallicSmoothness.x);

    //LIGHTING VECTORS
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 halfVector = normalize(lightDir + viewDir);
    float3 reflViewDir = reflect(-viewDir, worldNormal);
    float3 reflLightDir = reflect(lightDir, worldNormal);

    //DOT PRODUCTS FOR LIGHTING
    float ndl = saturate(dot(lightDir, worldNormal));
    float vdn = abs(dot(viewDir, worldNormal));
    float rdv = saturate(dot(reflLightDir, float4(-viewDir, 0)));

    #if defined(UNITY_PASS_FORWARDBASE)
        ndl = lerp(ndl, round(ndl*0.5+0.5), _ShadingStyle);
        //attenuation = lerp(attenuation, round(attenuation), _ShadingStyle);
    #endif

    //LIGHTING
    float3 lighting = float3(0,0,0);

    #if defined(LIGHTMAP_ON)
        float3 indirectDiffuse = 0;
        float3 directDiffuse = getLightmap(i.uv1, worldNormal, i.worldPos);
        #if defined(DYNAMICLIGHTMAP_ON)
            float3 realtimeLM = getRealtimeLightmap(i.uv2, worldNormal);
            directDiffuse += realtimeLM;
        #endif
    #else
            float3 indirectDiffuse;
            indirectDiffuse = ShadeSH9(float4(worldNormal, 1));

            indirectDiffuse = lerp(indirectDiffuse,  ShadeSH9(float4(0,0,0,1)), _ShadingStyle);
            
            float3 directDiffuse = ndl * _LightColor0;
            #ifdef UNITY_PASS_FORWARDADD
                directDiffuse *= attenuation;
            #endif
            directDiffuse += indirectDiffuse;

    #endif

    float3 indirectSpecular = getIndirectSpecular(i.worldPos, diffuseColor, vdn, metallicSmoothness, reflViewDir, indirectDiffuse, viewDir, directDiffuse);
    float3 directSpecular = getDirectSpecular(lightCol, diffuseColor, metallicSmoothness, rdv, attenuation);

    lighting = diffuse * directDiffuse; 
    lighting += directSpecular; 
    lighting += indirectSpecular;

    float2 screenUV = calcScreenUVs(i.screenPos);
    float dith = calcDither(screenUV);
    
    float alphaModifier = saturate( pow(1-(i.distanceFromOriginal), 80 * max(1-_CenterFalloff, .5)) );
    
    float4 borderTex = tex2D(_BorderTexture, i.worldPos.zy + (_Time.y*_ScrollSpeed)); 
    borderTex *= 1-alphaModifier;

    float al = diffuseColor.a ;
    al *= alphaModifier - (dith * (1-alphaModifier) * 0.15);

    float4 emissionTex = tex2D(_EmissionMap, i.uv) * _EmissionColor;
    float3 emission = pow(i.color.rgb, 5) * smoothstep(0,1,1-alphaModifier) * saturate(i.color.a);
    emission += borderTex.rgb * smoothstep(0,1,1-alphaModifier) * saturate(i.color.a) * _FalloffBrightness;
    
    float lightAvg = dot((_LightColor0 + indirectDiffuse) / 2, grayscaleVec);
    lighting += emission * 80 * lightAvg;
    lighting += emissionTex;

    return float4(lighting, al);
}
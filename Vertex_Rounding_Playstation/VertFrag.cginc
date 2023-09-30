// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
//This file contains the vertex and fragment functions for both the ForwardBase and Forward Add pass.
v2f vert (appdata v)
{
    v2f o;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 tangent = UnityObjectToWorldDir(v.tangent);
    float3 bitangent = cross(tangent, worldNormal);
    float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
    v.vertex = mul(unity_ObjectToWorld, v.vertex);
    v.vertex = round(v.vertex * _Rounding) / _Rounding;
    v.vertex = mul(unity_WorldToObject, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);

        o.uv = v.uv;
    #if defined(UNITY_PASS_FORWARDBASE)
    if(_UseVertexLightmapping == 0)
    {
        o.uv1 = v.uv1;
        o.uv2 = v.uv2;
    }
    else
    {
        o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
        o.uv2 = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;;
    }
    #endif
    
    #if !defined(UNITY_PASS_SHADOWCASTER)
    o.btn[0] = bitangent;
    o.btn[1] = tangent;
    o.btn[2] = worldNormal;
    o.worldPos = worldPos;
    o.objPos = v.vertex;
    o.objNormal = v.normal;
    o.color = v.color;
    

    UNITY_TRANSFER_SHADOW(o, o.uv);
    #else
    TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
    #endif

    return o;
}
			
fixed4 frag (v2f i) : SV_Target
{
    i.uv = round(i.uv * _TextureResolutionRounding) / _TextureResolutionRounding;

    #if defined(UNITY_PASS_FORWARDBASE)
        i.uv1 = round(i.uv1 * _TextureResolutionRounding) / _TextureResolutionRounding;
        i.uv2 = round(i.uv2 * _TextureResolutionRounding) / _TextureResolutionRounding;
    #endif

    #if defined(Cutout)
        float4 alphatex = tex2D(_MainTex, i.uv);
        clip(alphatex.a - _Cutoff);
    #endif
    //Return only this if in the shadowcaster
    #if defined(UNITY_PASS_SHADOWCASTER)
        SHADOW_CASTER_FRAGMENT(i);
    #else
        return CustomStandardLightingBRDF(i);
    #endif
}
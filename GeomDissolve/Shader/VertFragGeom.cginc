//This file contains the vertex, fragment, and Geometry functions for both the ForwardBase and Forward Add pass.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define V2F_SHADOW_CASTER_NOPOS float3 vec : TEXCOORD0;
#define TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o,opos) o.vec = mul(unity_ObjectToWorld, v[i].vertex).xyz - _LightPositionRange.xyz; opos = o.pos;
#else
#define V2F_SHADOW_CASTER_NOPOS
#define TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o,opos) \
        opos = UnityClipSpaceShadowCasterPos(v[i].vertex, v[i].normal); \
        opos = UnityApplyLinearShadowBias(opos);
#endif

float rand(float n){return frac(sin(n) * 43758.5453123);}

v2g vert (appdata v, uint vertID : SV_VertexID)
{
    v2g o = (v2g)0;
    o.vertex = v.vertex;
    o.uv = v.uv;
    o.vertID = vertID;
    #if defined(UNITY_PASS_FORWARDBASE)
        o.uv1 = v.uv1;
        o.uv2 = v.uv2;
    #endif
    
    o.normal = v.normal;
    o.tangent = v.tangent;

    return o;
}

[maxvertexcount(3)]
void geom(triangle v2g v[3], inout TriangleStream<g2f> tristream)
{
    g2f o = (g2f)0;

    float3 normal = normalize(cross(v[1].vertex.xyz - v[0].vertex.xyz, v[2].vertex.xyz - v[0].vertex.xyz));
    float3 triCenter = (v[0].vertex + v[1].vertex + v[2].vertex) / 3;
    float3 AvgWorldPos = mul(unity_ObjectToWorld, (v[0].vertex + v[1].vertex + v[2].vertex) / 3); 

    float progress = max(0, _CenterScale);

    float cdist = 0; 

    #if UNITY_SINGLE_PASS_STEREO
        float4 stereoCameraPos = mul(unity_StereoMatrixV[0], AvgWorldPos);
        cdist = length(stereoCameraPos.xy);
    #else
        float4 cameraPos = UnityObjectToViewPos(triCenter).xyzz;
        cdist = length(cameraPos.xy);
    #endif

    if(_GeoMode == 1) // Static Based Vertical
    {
        cdist = v[0].vertex.y + max(1, sin(_CenterScale));
    }
    if(_GeoMode == 2) // Time Based Vertical
    {
        cdist = v[0].vertex.y + sin(_Time.y);
    }

    cdist = smoothstep(0.1 * progress, progress, cdist);

    float mod = sin(_Time.y ) * 0.5 + 1;
    mod = smoothstep(0.4, 0.6, mod );

    float distToCamera = 1/distance(_WorldSpaceCameraPos, AvgWorldPos);
    float4 color = float4(rand(v[0].vertID), rand(v[1].vertID), rand(v[2].vertID), rand(v[0].vertID * sin(_Time.y) * 0.5 + 0.5)) * _RainbowBrightness;
    
    float timeMod = sin(_Time.y * (color.g * 2)) * 0.5 + 1;

    for (int i = 0; i < 3; i++)
    {
        v[i].vertex.xyz -= triCenter;
        v[i].vertex.xyz *= 1-cdist;
        v[i].vertex.xyz += triCenter;
        v[i].vertex.xyz += (cdist * normal * distToCamera * timeMod) * _ExplodeAmount * 5;

        o.pos = UnityObjectToClipPos(v[i].vertex);
        o.uv = TRANSFORM_TEX(v[i].uv, _MainTex);
        o.distanceFromOriginal = cdist * distToCamera;
        o.screenPos = ComputeScreenPos(o.pos);
        o.color = color;
        #if defined(UNITY_PASS_FORWARDBASE)
            o.uv1 = v[i].uv1;
            o.uv2 = v[i].uv2;
        #endif
        
        //Only pass needed things through for shadow caster
        #if !defined(UNITY_PASS_SHADOWCASTER)
            float3 worldNormal = UnityObjectToWorldNormal(v[i].normal);
            float3 tangent = UnityObjectToWorldDir(v[i].tangent);
            float3 bitangent = cross(tangent, worldNormal);

            o.btn[0] = bitangent;
            o.btn[1] = tangent;
            o.btn[2] = worldNormal;
            o.worldPos = mul(unity_ObjectToWorld, v[i].vertex);
            o.objPos = v[i].vertex;
            o.objNormal = v[i].normal;
            UNITY_TRANSFER_SHADOW(o, o.uv);
        #else
            TRANSFER_SHADOW_CASTER_NOPOS_GEOMETRY(o, o.pos);
        #endif
        tristream.Append(o);
    }
    tristream.RestartStrip();
}
			
fixed4 frag (g2f i) : SV_Target
{
    return CustomStandardLightingBRDF(i);
}
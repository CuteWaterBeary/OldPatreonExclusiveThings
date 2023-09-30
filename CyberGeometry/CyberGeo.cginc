sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _ScrollTex;
float4 _ScrollTex_ST;
float4 _Color;
float _Speed;
float _Brightness;
float _RimSize;
int _DotAmnt;
int _ScrollMainTex;
int _WorldSpaceUV;
float _SpeedMainTex;
float _DotOffset;
int _TextureOffset;
int _ut;
int _ul;
int _WorldSpaceUV2;
sampler2D _StaticMask;

#define HASHSCALE3 float3(.1031, .1030, .0973)

float2 hash22(float2 p)
{   
    float3 p3 = frac(float3(p.xyx) * HASHSCALE3 + (_Time.y * 0.00005));
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz)*p3.zy);
}  

float3 InterpTri(float3 a, float3 b, float3 c, float2 interp)
{
    return a + (b - a) * interp.x + (c - a) * interp.y;
}        

float2 InterpTri2(float2 a, float2 b, float2 c, float2 interp)
{
    return a + (b - a) * interp.x + (c - a) * interp.y;
}

v2g vert (appdata v, uint vertID : SV_VertexID)
{
    v2g o;
    o.vertex = v.vertex;
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.normal = v.normal;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.vertID = vertID;
    return o;
}

[maxvertexcount(16)]
void geom(triangle v2g IN[3], 
#if defined(Points)
    inout PointStream<g2f> tristream
#elif defined(Lines)
    inout LineStream<g2f> tristream
#else
    inout TriangleStream<g2f> tristream
#endif
)
{
    g2f o;

    fixed4 scrollTex = tex2Dlod(_ScrollTex, float4(lerp(IN[0].uv, IN[0].worldPos.xy, _WorldSpaceUV2) * _ScrollTex_ST.xy + (_Time.y * _Speed),0,0));
    scrollTex = lerp(0, scrollTex, _TextureOffset);

    IN[1].vertex.xyz += (_DotOffset * 0.02) * IN[1].normal * scrollTex;

    float4 clip0 = UnityObjectToClipPos(IN[0].vertex);
    float4 clip1 = UnityObjectToClipPos(IN[1].vertex);
    float4 clip2 = UnityObjectToClipPos(IN[2].vertex);

    const half2 v0 = clip0.xy / clip0.w;
    const half2 v01 = (clip1.xy / clip1.w) - v0;
    const half2 v02 = (clip2.xy / clip2.w) - v0;
    float area = length(cross(float3(v01.xy, 0), float3(v02.xy, 0))) * 500;
    
    float scalars = 0;
    #if defined(Points)
        scalars = 1;
    #elif defined(Lines)
        scalars = 2;
    #else
        scalars = 3;
    #endif
    float dotAmount = lerp(scalars, _DotAmnt, saturate(area));
    for (int i = 0; i < dotAmount; i++)
    {
        float2 randHash = hash22(float2(IN[0].vertID * 0.02 + i, IN[1].vertID * 0.12 + i));
        randHash = randHash.x + randHash.y > 1 ? float2(1, 1) - randHash : randHash;
        float3 pos = InterpTri(IN[0].vertex, IN[1].vertex, IN[2].vertex, randHash);
        float3 normal = InterpTri(IN[0].normal, IN[1].normal, IN[2].normal, randHash);
        float4 worldPos = float4(InterpTri(IN[0].worldPos, IN[1].worldPos, IN[2].worldPos, randHash), 1);
        float2 uv = InterpTri2(IN[0].uv, IN[1].uv, IN[2].uv, randHash);

        o.vertex = UnityObjectToClipPos(pos);
        o.uv = uv;
        o.normal = UnityObjectToWorldNormal(IN[1].normal);
        o.worldPos = worldPos;
        tristream.Append(o);
    }
    // tristream.RestartStrip();
}

fixed4 frag (g2f i) : SV_Target
{

    i.normal = normalize(i.normal);
    float dist = distance(i.worldPos, _WorldSpaceCameraPos);
    
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    float4 diffuse = tex2D(_MainTex, lerp(i.uv, i.worldPos.xy, _WorldSpaceUV) * _MainTex_ST.xy + _MainTex_ST.zw + lerp(0, _Time.y * _SpeedMainTex, _ScrollMainTex)) * _Color;
    fixed4 scrollTex = tex2D(_ScrollTex, lerp(i.uv, i.worldPos.xy, _WorldSpaceUV2) * _ScrollTex_ST.xy + (_Time.y * _Speed)) ;
    float4 staticMask = tex2D(_StaticMask, i.uv);
    float vdn = abs(dot(viewDir, i.normal));
    vdn = smoothstep(_RimSize - 1, _RimSize + 1, vdn);
    float distScalar = dist * dist;
    #if defined(Triangles) 
        distScalar = 1;
    #endif
    
    float4 finalCol = ((1-vdn) * diffuse * scrollTex) / distScalar;
    return float4(finalCol.rgb * _Brightness * staticMask.r, (1-vdn) );
}


sampler2D _MainTex;
sampler2D _ScrollingTex;
sampler2D _StarTexture;
float4 _Color;
float4 _Color2;
float _WireThickness;
float _TriangleScale;
float _StarCycleSpeed;
float _LineCycleSpeed;
float _LineScrolling;
float _DotsScrolling;
float _LineAlbedo;
float _DotsAlbedo;
float _ScrollSpeed; 
float _StarTravelSpeed;
float _SpriteScaleBack;
float _ScaleJitter;
float _AnimationSpeed;
float _TotalFrames;
float _RotationSpeed;
int _JitterScroll;
int _CycleStars;
int _CycleLines;
int _SheetCol;
int _SheetRow;
int _SizeAnim;

float rand(float n){return frac(sin(n) * 43758.5453123);}

v2g vert (appdata v, uint vertID : SV_VertexID)
{
    v2g o;
    o.vertex = v.vertex;
    o.uv = v.uv;
    o.normal = v.normal;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.vertID = vertID;
    return o;
}

bool IsInMirror()
{
    return unity_CameraProjection[2][0] != 0 || unity_CameraProjection[2][1] != 0;
}

float2 getSprite(float2 uv, int framenum, int cols, int rows, float modifier) 
{
    framenum += frac((_Time.y * max(0, _AnimationSpeed)) + modifier) * _TotalFrames;
    
    float frame = clamp(framenum, 0, cols*rows);

    float2 offPerFrame = float2((1 / (float)cols), (1 / (float)rows));

    float2 spriteSize = uv;
    spriteSize.x = (spriteSize.x / cols);
    spriteSize.y = (spriteSize.y / rows);

    float2 currentSprite = float2(0,  1 - offPerFrame.y);
    currentSprite.x += frame * offPerFrame.x;
    
    float rowIndex;
    float mod = modf(frame / (float)cols, rowIndex );
    currentSprite.y -= rowIndex * offPerFrame.y;
    currentSprite.x -= rowIndex * cols * offPerFrame.x;
    
    return (spriteSize + currentSprite);
}

void rotSprite(inout float2 pos, float speed)
{
    float sinX = sin ( speed * _Time.y );
    float cosX = cos ( speed * _Time.y );
    float sinY = sin ( speed * _Time.y );
    float2x2 rotationMatrix = float2x2( cosX, -sinX, sinY, cosX);
    pos.xy = mul ( pos.xy, rotationMatrix );
}

[maxvertexcount(7)]
void geom(triangle v2g v[3], inout TriangleStream<g2f> tristream)
{
    g2f o;
    #if UNITY_SINGLE_PASS_STEREO
        float3 cameraPos = float3((unity_StereoWorldSpaceCameraPos[0]+ unity_StereoWorldSpaceCameraPos[1])*.5); 
    #else
        float3 cameraPos = _WorldSpaceCameraPos;
    #endif

    
    float3 avgWPos = (v[0].worldPos + v[1].worldPos + v[2].worldPos) / 3;
    float3 avgWNormal = mul(unity_ObjectToWorld, (v[0].normal + v[0].normal + v[0].normal) / 3);
    float3 viewDir = normalize(cameraPos - avgWPos);
    float vdn = dot(avgWNormal, viewDir);

    float3 p0 = v[0].worldPos.xyz;
    float3 p1 = v[1].worldPos.xyz;
    float3 p2 = v[2].worldPos.xyz;

    float3 triangleNormal = normalize(cross(p1 - p0, p2 - p0));
    float2 baryCoords[3] = {
                            float2(1, 0),
                            float2(0, 1),
                            float2(0, 0)
                            };

    //Generate Lines
    for(int i = 0; i < 3; i++)
    {

        o.vertex = UnityObjectToClipPos(v[i].vertex);
        o.uv = v[i].uv;
        o.uv1 = v[i].uv;
        o.bary = baryCoords[i];
        o.isLine = 1;
        o.color = saturate( sin(_Time.y * _LineCycleSpeed * rand(v[2].vertID )) );
        o.worldPos = v[i].worldPos;
        tristream.Append(o);
    }
    tristream.RestartStrip();


    //Generate Billboarded Quads
    float baseMod = rand(v[2].vertID);
    float modifier = saturate( sin(_Time.y * _StarCycleSpeed * baseMod) );
    float f = _TriangleScale * 0.03 * lerp(1 , clamp(rand((v[2].vertID + rand(v[1].vertID)) ), 0.5, 1), _ScaleJitter) * lerp(1, modifier, _SizeAnim);

    float3 dist1 = v[2].vertex.xyz - v[1].vertex.xyz;
    float3 dist2 = v[1].vertex.xyz - v[0].vertex.xyz;
    float area = length(cross(dist1, dist2)) * 0.5;
    area += baseMod * 0.0001;

    if(vdn > 0 && area > (_SpriteScaleBack * 0.0001) )
    {
        float2 quadVerts[4] = {               /*-1,1  1,1*/
                               float2(-f,-f), /*-1,1  1,-1*/
                               float2(-f,f),
                               float2(f,-f),
                               float2(f,f)
                              };
    
        float2 quadUV[4] = {
                            float2(0,0),
                            float2(0,1),
                            float2(1,0),
                            float2(1,1)
                           };

        for(int j = 0; j < 4; j++)
        {
            if(IsInMirror())
            {
                quadVerts[j].x = -quadVerts[j].x; // fix billboards in mirrors
                quadUV[j].x = 1-quadUV[j].x;
            }

            float3 vertPos = lerp(v[1].vertex.xyz, v[2].vertex.xyz, sin(_Time.y * rand(v[2].vertID) * _StarTravelSpeed) * 0.5 + 0.5);
            float3 centerPos = UnityObjectToViewPos(float4(vertPos, 1));

            rotSprite(quadVerts[j].xy, _RotationSpeed * baseMod); 

            
            float3 quad = centerPos + float3(quadVerts[j], 0);

            o.vertex = mul(UNITY_MATRIX_P, float4(quad, 1));



            float2 uv = getSprite(quadUV[j], 0, _SheetCol, _SheetRow, baseMod);
            o.uv = uv;
            o.uv1 = v[0].uv;
            o.bary = 0;
            o.color = saturate( sin(_Time.y * _StarCycleSpeed * rand(v[2].vertID)) );
            o.isLine = 0;
            o.worldPos = v[0].worldPos;
            tristream.Append(o);
        }
    }
}

float3 getWireframe(float2 baryCoords) 
{
    float3 barys;
    barys.xy = baryCoords;
    barys.z = 1 - barys.x - barys.y;
    float minBary = min(barys.x, min(barys.y, barys.z));
    minBary = smoothstep(0, _WireThickness, minBary);
    return smoothstep(0.5, 0.6, 1-minBary);
}

// float3 getDots(float2 uv)
// {
//     float2 nearest = 2 * frac(2 * uv) - 1;;
//     float dist = length(nearest);
//     float dotSize = 1;
//     float dotMask = step(dotSize, dist);

//     return (1-dotMask) * _Color2;
// }

fixed4 frag (g2f i, bool facing: SV_IsFrontFace) : SV_Target
{
    float3 col;
    float4 albedo = tex2D(_MainTex, i.uv1);
    if(i.isLine != 0) //Lines
    {
        float4 scrollingTex = tex2D(_ScrollingTex, float2(i.worldPos.x, i.worldPos.y + (_Time.y * _ScrollSpeed)) );
        col = getWireframe(i.bary) * lerp(1, i.color.r, _CycleLines) * _Color  * lerp(1, albedo, _LineAlbedo) * lerp(1, scrollingTex, _LineScrolling);
    }
    else // Stars
    {
        float4 emojis = tex2D(_StarTexture, i.uv);
        float jitter = rand(i.uv1) * _JitterScroll;
        float4 scrollingTex = tex2D(_ScrollingTex, float2(i.worldPos.x, i.worldPos.y + (_Time.y * _ScrollSpeed + jitter)) );
        col = emojis * _Color2 * lerp(1,i.color.r,_CycleStars) * lerp(1, albedo, _DotsAlbedo) * lerp(1, scrollingTex, _DotsScrolling);
    
    }

    return float4(col, 1);
}


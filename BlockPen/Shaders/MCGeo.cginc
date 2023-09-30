sampler2D _MainTex;
sampler2D _DestroyTex;
float4 _MainTex_ST;
float4 _MainTex_TexelSize;
float4 _Color;
float4 _InteriorColor;
float _Brightness;
float _Size;
int _Rounding;
int _Pulse;

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

half calcDither(half2 screenUV)
{
    half dither = Dither8x8Bayer(fmod(screenUV.x, 8), fmod(screenUV.y, 8));
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

float4 GetVertexPositionOffsets_Cube(int index, float scale)
{
    //Array that holds all of the vertex positions for each face of a cube, with scale control
    //Each section of 4 float4's holds the vertex position's for one quad, and a cube is constructed of
    //6 quads, so we have 24 float4s.
    float f = scale;
    float4 v[24] = 
    {
        float4(f,f,f, 0),
        float4(f,-f,f, 0),
        float4(f,-f,-f, 0),
        float4(f,f,-f, 0),
        //-----------------
        float4(-f,f,f, 0),
        float4(f,f,f, 0),
        float4(f,f,-f, 0),
        float4(-f,f,-f, 0),
        //-----------------
        float4(f,f,f, 0),
        float4(-f,f,f, 0),
        float4(-f,-f,f, 0),
        float4(f,-f,f, 0),
        //-----------------
        float4(-f,f,-f, 0),
        float4(-f,-f,-f, 0),
        float4(-f,-f,f, 0),
        float4(-f,f,f, 0),
        //-----------------
        float4(f,-f,f, 0),
        float4(-f,-f,f, 0),
        float4(-f,-f,-f, 0),
        float4(f,-f,-f, 0),
        //-----------------
        float4(-f,f,-f, 0),
        float4(f,f,-f, 0),
        float4(f,-f,-f, 0),
        float4(-f,-f,-f, 0)
    };

    return v[index];
}

float2 GetVertexUV_Cube(int index)
{
    //Array that hold all the possible UVs for a cube.
    float2 uvs[24] = 
    {
        //Left
        float2(1,1),
        float2(1,0),
        float2(0,0),
        float2(0,1),
        //Top
        float2(0,1), //UVs are offset out of 0 - 1 range because of math that happens to figure
        float2(0,2), //out which box is selected.
        float2(1,2),
        float2(1,1),
        //Front
        float2(0,1),
        float2(1,1),
        float2(1,0),
        float2(0,0),
        //Right
        float2(1,1),
        float2(1,0),
        float2(0,0),
        float2(0,1),
        //Bottom
        float2(0,-1), //UVs are offset out of 0 - 1 range because of math that happens to figure
        float2(0,0), //out which box is selected.
        float2(1,0),
        float2(1,-1),
        //Back
        float2(0,1),
        float2(1,1),
        float2(1,0),
        float2(0,0)
    };

    return uvs[index];
}

float2 GetVertexUV_Cube_Raw(int index)
{
    float2 uvs[4] = {
        float2(0,0),
        float2(0,1),
        float2(1,1),
        float2(1,0)
    };
    return uvs[index];
}

float3 GetVertexNormals_Cube(int index)
{
    float3 normals[6] = 
    {
        float3(1,0,0), //left
        float3(0,1,0), //top
        float3(0,0,1), //front
        float3(-1,0,0), //right
        float3(0,-1,0), //bottom
        float3(0,0,-1) //back
    };

    return normals[index];
}


v2g vert (appdata v, uint vertID : SV_VertexID)
{
    v2g o;
    o.vertex = v.vertex;
    o.uv = float4(v.uv.xy, 0, 0);
    o.normal = v.normal;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.vertID = vertID;
    o.color = v.color;
    return o;
}

[maxvertexcount(36)]//We only need to do 36 verts maximum. And we only take the first vertex in from the original mesh.
void geom(point v2g IN[1], inout TriangleStream<g2f> tristream)
{   
    //Shared between both the Selector and the placed Blocks
    bool isPreviewBlock = step(IN[0].color.b, 0.5);
    float3 center = IN[0].worldPos.xyz;
    float rounding = 0.5 * (1/_Size);
    float3 roundedCenter = round(center * rounding) / rounding;
    float blockScale = lerp(_Size, _Size + 0.005 + (sin(_Time.y * 5) * 0.001), _Pulse);

    #if !defined(VoxelSelector)
    //Init the struct for the geo to fragment shader.
        g2f o[24] = (g2f[24])0;
    //Because we wanted to be able to choose blocks, I chose the approach of comparing two vectors -
    //The raw position, and the position of where the center of the current grid cell is.
    //This allows us to divide the grid cell into 8 different smaller cells, and change the texture
    //based on where in those cells the raw position is.
        int textureSelect = 0;
        bool up = step(center.y - roundedCenter.y, 0);
        bool forward = step(center.z - roundedCenter.z, 0);
        bool side = step(center.x - roundedCenter.x, 0);      
        if(up && forward && side)
            textureSelect = 0;

        if(up && forward && !side)
            textureSelect = 1;

        if(up && !forward && side)
            textureSelect = 2;

        if(up && !forward && !side)
            textureSelect = 3;
        
        if(!up && forward && side)
            textureSelect = 4;

        if(!up && forward && !side)
            textureSelect = 5;

        if(!up && !forward && side)
            textureSelect = 6;

        if(!up && !forward && !side)
            textureSelect = 7;
        
        //if its the preview selection block, we want the scale to be smaller, and
        //we want the center to be the raw center, so that it smoothly tracks, and we can see more clearly where
        //we are relative to the grid cell.        
        if(isPreviewBlock)
        {
            blockScale *= 0.5;
            roundedCenter = center;
        }

        // Assign new vertices positions (24 new vertices, forming a cube)
        // Also calculate worldPos, uvs, and normals, etc
        for (int i = 0; i < 24; i++) 
        { 
            float4 vertexPosition = float4(roundedCenter, 1) + (GetVertexPositionOffsets_Cube(i, blockScale));
            vertexPosition = mul(unity_WorldToObject, vertexPosition);
            
            //Since we're using a texture sheet that is 8 "textures" wide, and 3 tall, we need to
            //divide the UVs by that, which will put the default at 0,0, the bottom left corner of the texture sheet.
            //we add the texture select from before to get the offsets for the different block types.
            float2 uv = (GetVertexUV_Cube(i) + textureSelect) * _MainTex_ST.xy + _MainTex_ST.zw;
            uv.x /= 8.0000000;
            uv.y /= 3;

            o[i].vertex = UnityObjectToClipPos(vertexPosition);
            o[i].uv = float4(uv, 0, 0);
            o[i].uv1 = GetVertexUV_Cube(i);
            o[i].normal = GetVertexNormals_Cube(i/4);
            o[i].worldPos = float4(0,0,0, 1);
            o[i].color = IN[0].color;
        }

        // Build the cube
        for (int i = 0; i < 6 ; i++)
        {
            tristream.Append(o[i*4 + 0]);
            tristream.Append(o[i*4 + 1]);
            tristream.Append(o[i*4 + 3]);
            tristream.Append(o[i*4 + 2]);
            tristream.RestartStrip();
        }
    #else
        //SELECTOR BORDERS
        //This is all the same as above, but in this case, we init with 36 verts, because we are constucting a cube, and
        //3 quads that intersect to form a grid within the cube.
        g2f o[36] = (g2f[36])0;

        //First loop for the cube itself, the selector shell
        for (int i = 0; i < 24; i++) 
        { 
            float4 vertexPosition = float4(roundedCenter, 1) + GetVertexPositionOffsets_Cube(i, blockScale);
            vertexPosition = mul(unity_WorldToObject, vertexPosition);
            float2 uv = GetVertexUV_Cube_Raw(i%4) * 0.5;

            o[i].vertex = UnityObjectToClipPos(vertexPosition);
            o[i].uv = float4(uv, 0, 0);
            o[i].color = IN[0].color;
            o[i].colorTint = 0;
            o[i].normal = GetVertexNormals_Cube(i/4);
            o[i].screenPos = ComputeScreenPos(o[i].vertex);
            o[i].worldPos = float4(0,0,0,1);
        }

        // Build the cube
        for (int i = 0; i < 6 ; i++)
        {
            tristream.Append(o[i*4 + 0]);
            tristream.Append(o[i*4 + 1]);
            tristream.Append(o[i*4 + 3]);
            tristream.Append(o[i*4 + 2]);
            tristream.RestartStrip();
        }

        //Second loop for the Selector Interior Grid
        for (int i = 0; i < 12; i++) 
        { 
            float3 normal = GetVertexNormals_Cube(i/4);
            //If we subtract the block scale, multiplied by the normal direction, we can re-center the quads so that they intersect and form the grid.
            float4 vertexPosition = float4(roundedCenter, 1) + GetVertexPositionOffsets_Cube(i, blockScale) - (blockScale * float4(normal,0));
            vertexPosition = mul(unity_WorldToObject, vertexPosition);
            float2 uv = GetVertexUV_Cube_Raw(i%4) * 0.5;
            //Add .5 to the vertical position of the UV since our selector texture sheet has the center bit positioned above the
            //exterior texture.
            uv.y += 0.5;

            o[i].vertex = UnityObjectToClipPos(vertexPosition);
            o[i].uv = float4(uv, 0, 0);
            o[i].color = IN[0].color;
            o[i].colorTint = 1;
            o[i].normal = normal;
            o[i].screenPos = ComputeScreenPos(o[i].vertex);
            o[i].worldPos = float4(0,0,0,1);
        }

        //build grid inside of cube
        for (int i = 0; i < 3 ; i++)
        {
            tristream.Append(o[i*4 + 0]);
            tristream.Append(o[i*4 + 1]);
            tristream.Append(o[i*4 + 3]);
            tristream.Append(o[i*4 + 2]);
            tristream.RestartStrip();
        }

    #endif
}

fixed4 frag (g2f i) : SV_Target
{
    i.normal = normalize(i.normal);
    float4 diffuse = 0;
    float4 color = 0;

    #if !defined(VoxelSelector)
        //uvs get divided by 10 for the destroying animation sheet,
        //and the position on the texture sheet then gets moved by the green vertex color channel,
        //rounded to a factor of 10, and that gives us 10 "frames" as the green channel goes from 0, to 1
        i.uv1.x *= 0.1;
        i.uv1.x += round(i.color.g * 10) / 10;
        
        float4 destroyAnim = tex2D(_DestroyTex, i.uv1.xy);
        color = tex2D(_MainTex, i.uv.xy);
        diffuse = color * _Color * destroyAnim;
    #else
        //just normal dithering stuff, take the screen pos, convert to a UV coordinate, and then get the dither matrix on the screen from that.
        float2 screenUV = calcScreenUVs(i.screenPos);
        float dither = calcDither(screenUV);
        color = tex2D(_MainTex, i.uv.xy) * lerp(_Color, _InteriorColor, i.colorTint);
        
        //Do the dithering with clip, wow
        clip(color.a - dither);
        diffuse = color * _Brightness;
    #endif

    // float3 indirect = ShadeSH9(float4(i.normal.xyz, 1)); 
    // float ndl = saturate(dot(_WorldSpaceLightPos0, i.normal));
    // float4 lighting = ndl * _LightColor0;

    return float4(diffuse.rgb, color.a);
}


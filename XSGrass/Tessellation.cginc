// Tessellation programs based on this article by Catlike Coding:
// https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/

float UnityDistanceFromPlane (float3 pos, float4 plane)
{
    float d = dot (float4(pos,1.0f), plane);
    return d;
}

// Returns true if triangle with given 3 world positions is outside of camera's view frustum.
// cullEps is distance outside of frustum that is still considered to be inside (i.e. max displacement)
bool UnityWorldViewFrustumCull (float3 wpos0, float3 wpos1, float3 wpos2, float cullEps)
{
    float4 planeTest;

    // left
    planeTest.x = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[0]) > -cullEps) ? 1.0f : 0.0f );
    // right
    planeTest.y = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[1]) > -cullEps) ? 1.0f : 0.0f );
    // top
    planeTest.z = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[2]) > -cullEps) ? 1.0f : 0.0f );
    // bottom
    planeTest.w = (( UnityDistanceFromPlane(wpos0, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos1, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f ) +
                  (( UnityDistanceFromPlane(wpos2, unity_CameraWorldClipPlanes[3]) > -cullEps) ? 1.0f : 0.0f );

    // has to pass all 4 plane tests to be visible
    return !all (planeTest);
}

struct TessellationFactors 
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

vertexInput vert(vertexInput v)
{
    vertexInput o;

    o.vertex = v.vertex;
    o.uv = v.uv;
    o.normal = v.normal;
    o.tangent = v.tangent;
    o.color = v.color;
    o.uv2 = v.uv2;
	return o;
}

vertexOutput tessVert(vertexInput v)
{
    vertexOutput o;

    o.vertex = v.vertex;
    o.uv = v.uv;
    o.normal = v.normal;
    o.tangent = v.tangent;
    o.color = v.color;
    o.uv2 = v.uv2;
    return o;
}

float UnityCalcDistanceTessFactor (float4 vertex, float minDist, float maxDist, float tess)
{
    float3 wpos = mul(unity_ObjectToWorld,vertex).xyz;
    float dist = distance (wpos, _WorldSpaceStereoCameraCenterPos);
    float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
    f = round(f);
    f = f < 0.5 ? 0 : f;

    return f;
}

float4 UnityCalcTriEdgeTessFactors (float3 triVertexFactors)
{
    float4 tess;
    tess.x = 0.5 * (triVertexFactors.y + triVertexFactors.z);
    tess.y = 0.5 * (triVertexFactors.x + triVertexFactors.z);
    tess.z = 0.5 * (triVertexFactors.x + triVertexFactors.y);
    tess.w = (triVertexFactors.x + triVertexFactors.y + triVertexFactors.z) / 3.0f;
    return tess;
}

// Distance based tessellation:
// Tessellation level is "tess" before "minDist" from camera, and linearly decreases to 1
// up to "maxDist" from camera.
float4 UnityDistanceBasedTess (float4 v0, float4 v1, float4 v2, float minDist, float maxDist, float tess)
{
    float3 f;
    f.x = UnityCalcDistanceTessFactor (v0,minDist,maxDist,tess);
    f.y = UnityCalcDistanceTessFactor (v1,minDist,maxDist,tess);
    f.z = UnityCalcDistanceTessFactor (v2,minDist,maxDist,tess);

    return UnityCalcTriEdgeTessFactors (f);
}

float TessEdgeFactor(float3 p0, float3 p1)
{
	float edgeLength = distance(p0, p1);

	float3 edgeCenter = (p0 + p1) * 0.5;
	float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);
    float tessFactor = lerp(1, 0, _TessellationUniform) * 50;
	return edgeLength * _ScreenParams.y / (tessFactor * viewDistance) ;
}

TessellationFactors patchConstantFunction (InputPatch<vertexInput, 3> patch)
{
	TessellationFactors f;
    float maxTessellation = _TessellationUniform *= 50;

    float4 p0 = patch[0].vertex; 
    float4 p1 = patch[1].vertex; 
    float4 p2 = patch[2].vertex; 
    
    float bias = 0.4;
    float3 p0w = mul(unity_ObjectToWorld,p0);
    float3 p1w = mul(unity_ObjectToWorld,p1);
    float3 p2w = mul(unity_ObjectToWorld,p2);
    
    float4 tess = 0;
    if(UnityWorldViewFrustumCull(p0w, p1w, p2w, bias))
    {
        tess = 0;
    }
    else
    {
        _TessellationUniform *= 50;
        tess = UnityDistanceBasedTess(p0, p1, p2, _TessFar * _RenderDistanceFalloff, _TessFar, maxTessellation);
    }
    
    f.edge[0] = tess;
    f.edge[1] = tess;
    f.edge[2] = tess;
    f.inside = tess;

    return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
//[UNITY_partitioning("fractional_odd")]
//[UNITY_partitioning("fractional_even")]
//[UNITY_partitioning("pow2")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
vertexInput hull (InputPatch<vertexInput, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

[UNITY_domain("tri")]
vertexOutput domain(TessellationFactors factors, OutputPatch<vertexInput, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
{
	vertexInput v;

	#define DOMAIN_INTERPOLATE(fieldName) v.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

	DOMAIN_INTERPOLATE(vertex)
    DOMAIN_INTERPOLATE(uv)
    DOMAIN_INTERPOLATE(normal)
    DOMAIN_INTERPOLATE(tangent)
    DOMAIN_INTERPOLATE(color)
    DOMAIN_INTERPOLATE(uv2) 

	return tessVert(v);
}
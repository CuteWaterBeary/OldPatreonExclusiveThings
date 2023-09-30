Shader "Xiexe/Patreon/CorruptedLight"
{
    Properties
    {   
        [Header(MAIN)]
        _MainTex ("Main Texture", 2D) = "white" {}
        [HDR]_Color("Color Tint", Color) = (1,1,1,1)

        [Space(16)]
        [Header(CORRUPTION)]
        _CorruptionNoise("Corruption Texture", 2D) = "black" {}
        _CorruptionScale("Corruption Scale", float) = 1
        _CorruptionCloudScale("Corruption Cloud Scale", float) = 1
        _CorruptionCutoff("Corruption Cutoff", Range(0,1)) = 0.2

        [Space(16)]
        [Header(EMISSION)]
        _EmissionMap("Emission Map", 2D) = "white" {}
        _EmissionIntensity("Emission Intensity", Float) = 0
        _EmissionMainTexMultiply("Emission Maintex Multiply", Range(0,1)) = 0

        [Space(16)]
        [Header(GRADIENT)]
        _UpperBound("Gradient Upper Limit", Float) = 0.8
        _LowerBound("Gradient Lower Limit", Float) = -0.3
        [Enum(X UP, 0, Y UP, 1, Z UP, 2)] _UpDirection ("Local Up Direction", Int) = 1
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="Opaque" "DisableBatching"="true"}
        Pass
        {
            Tags{ "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            #define grayscaleVec float3(0.2125, 0.7154, 0.0721) //This grayscale vector will allow us to get a grayscale result of anything we do a dot product against with it.
            
            //This struct is the data being pulled from the mesh by Unity. In this case, we only need the vertex position, uvs, and vertex normals.
            //By default, these are all in Object Space.
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            //This struct is where the data calculated from the vertex shader will go to be passed to the fragment shader.
            //In this case, we are going to need; 
            //Vertex Clip Pos(always needed), uv, Object Space vertex position, World Space Vertex Position, World Space Vertex Normals, and the Vertex Screen Position
            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 objPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
            };

            //Initialize all of our properties from the Properties block at the top of the shader.
            sampler2D _MainTex;
            sampler2D _CorruptionNoise;
            sampler2D _EmissionMap;
            float4 _MainTex_ST;
            float4 _CorruptionNoise_ST;
            float4 _EmissionMap_ST;
            float4 _Color;
            float _EmissionIntensity;
            float _EmissionMainTexMultiply;
            float _UpperBound;
            float _LowerBound;
            float _CorruptionScale;
            float _CorruptionCloudScale;
            float _CorruptionCutoff;
            int _UpDirection;
            //--

            //Used for transparency only
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
            //---

            v2f vert (appdata v)
            {
                //Initialize and fill out our v2f struct.
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //v.vertex is just the object space vertex position.
                o.objPos = v.vertex;
                o.uv = v.uv;
                //use a built in unity macro to get the world space normal from the object space normal.
                o.normal = UnityObjectToWorldNormal(v.normal);
                //use matrix multiplication to get the world space position of the vertex
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                //get the screen position of the verts with a built in macro.
                o.screenPos = ComputeScreenPos(o.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {   
                //i.normal = normalize(i.normal);
                //Sample the main texture
                fixed4 col = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                //return col;

                //This is just some dithering math to get our "transparency" support.
                float2 screenUV = calcScreenUVs(i.screenPos);
                float dither = calcDither(screenUV);
                clip(col.a - dither); //We can call Clip on this early to avoid doing anything for pixels that get clipped. This saves us some performance if we do it before we do anything else.

                //Get the dot product of our main texture and the grayscale vector defined above. This will give us a grayscale version of our albedo texture.
                float4 grayscale = dot(col, grayscaleVec);
                //return grayscale;

                //Get the view direction, which allows us to get a fresnel around the model by getting a dot product
                //between the view direction, and the world space normal. This gives us our rimlight. Fresnel == Rimlight.
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float vdn = dot(viewDir, i.normal);
                float fresnel = smoothstep(0.65,0,vdn);
                //return fresnel;

                //Get our vertical gradient. This switch statement here just allows us to control the up direction of the gradient in
                //the event that our model has a weird up direction. (Blender file imports have Z up instead of Y)
                //This again is using the Object Position, because we want the vertical gradient to always remain vertical relative to the model.
                //If this was using World Position instead, when the model rotated, the gradient would not rotate with the model.
                float up = 0;
                switch(_UpDirection)
                {
                    case 0:
                        up = i.objPos.x;
                    break;

                    case 1:
                        up = i.objPos.y;
                    break;

                    case 2:
                        up = i.objPos.z;
                    break;
                }
                float4 verticalGrad = smoothstep(_LowerBound, _UpperBound, -up);
                //return verticalGrad;

                //Add the fresnel and the vertical gradient together, then multiply that result against the vertical gradient.
                //This will give us a combined fresnel and gradient that we can use to drive where we show the grayscale version of our albedo texture, and where we fade to our color.
                //Saturate it so that it does not go above 1 or below 0. Saturate is just clamps a value from 0-1.
                float lerpVector = saturate(verticalGrad * (fresnel + verticalGrad));
                //return lerpVector;

                //Sample the same texture three times, with scaled UVs. This allows them to be layered together without any noticable patterns emerging. 
                //The more layers you add to this, the better the effect that you can achieve, but the more expensive it gets.
                //These textures are mapped using object position as the UVs so that we get consistent scale regardless of the models real UVs.
                //We can then add to the UVs or subtract based on Time in order to offset them over time, creating an animated look.
                float4 corruptNoiseLayer1 = tex2D(_CorruptionNoise, (i.objPos.xy * 5  * _CorruptionScale));
                float4 corruptNoiseLayer2 = tex2D(_CorruptionNoise, (i.objPos.xz * 10 * _CorruptionScale) + (_Time.y * 0.5));
                float4 corruptNoiseLayer3 = tex2D(_CorruptionNoise, (i.objPos.yx * 15 * _CorruptionScale) - (_Time.y * 0.1));
                float4 combinedNoise = corruptNoiseLayer1 * corruptNoiseLayer2 * corruptNoiseLayer3 * 3; //Multiply all the layers together
                combinedNoise = dot(grayscaleVec, combinedNoise); // Convert the result to grayscale by getting the dot product between it, and the grayscale vector we have.
                //return combinedNoise;

                float boundsOffset = 0.03;
                float corruption = step(_CorruptionCutoff, combinedNoise); // "Trim" the resulting grayscale values down a bit, so that we have small "dots" of corruption around the model.
                float corruptionBounds = corruption; // Store as a black/white mask
                float corruptionInnerMask = step(_CorruptionCutoff + boundsOffset, combinedNoise);      
                corruption = corruption + (((1-corruptionInnerMask) * corruptionBounds) * 2);  
                corruption *= 0.1; // Darken the corruption a bit.
                corruption *= (1-verticalGrad) * 0.5; // Make our corruption fade in to being visible only in the upper parts of the gradient
                //return corruption;
                
                //Do the same as above, but for a different layer. This is the "darkness" layer that is underneath the brighter spots.
                float4 corruptNoiseCloudLayer1 = tex2D(_CorruptionNoise, (i.objPos.xy * _CorruptionCloudScale));
                float4 corruptNoiseCloudLayer2 = tex2D(_CorruptionNoise, (i.objPos.xz * 2 * _CorruptionCloudScale) + (_Time.y * 0.1));
                float4 corruptNoiseCloudLayer3 = tex2D(_CorruptionNoise, (i.objPos.xy * 4 * _CorruptionCloudScale) - (_Time.y * 0.2));
                float4 corruptionClouds = corruptNoiseCloudLayer1 * corruptNoiseCloudLayer2 * corruptNoiseCloudLayer3 * 3; //In this case, i'm multiplying by 3 here because it makes the defaults look a little bit better. This is actually something that is recommended by Blizzard.
                corruptionClouds = dot(corruptionClouds, grayscaleVec);
                corruptionClouds = smoothstep(0, 0.4, corruptionClouds);
                //return corruptionClouds;
                
                //Sample our emission texture and multiply it by our emission intensity. Normally you'd use a color property here, but because this is grayscale until the very end
                //we can just use a float for our intensity.
                //We can then choose to multiply it by 1, or our grayscale texture, which will allow us to influence wether or not our grayscale texture changes the intensity in areas.
                //Then, of course, we make sure that we grayscale it with the dot product.
                float4 emission = tex2D(_EmissionMap, i.uv * _EmissionMap_ST.xy + _EmissionMap_ST.zw) * lerp(1, grayscale, _EmissionMainTexMultiply) * _EmissionIntensity;
                emission = dot(grayscaleVec, emission);
                //return emission;
                
                //Initialize a float4 for our final color.
                float4 finalColor;
                //First, lerp between our grayscaled albedo and white based on our lerp vector. Then, multiply by a low value or 1 based on our lerp vector to darken the top of the model.
                //Then, add our corruption effect. Clamp it from 0-1 with saturate.
                finalColor = saturate(lerp(grayscale, 1, lerpVector) * lerp(0.01, 1, lerpVector) + corruption);
                finalColor = finalColor * lerp(1-corruptionClouds, 1, verticalGrad); //multiply the result by an inverted version of our corruption clouds, or 1, based on the vertical gradient. This means the clouds will only be visible in the dark areas.
                finalColor += emission; // Add our emission on top.
                finalColor *= _Color; // Multiply everything by our color property.

                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return float4(finalColor.xyz, 1);
            }
            ENDCG
        }
    }
}

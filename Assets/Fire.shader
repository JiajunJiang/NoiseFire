Shader "Unlit/Fire"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float WhiteNoise(int seed, int i, int j)
            {
                float r = frac(sin(dot(float2(i, cos(j)), float2(float(seed) + 12.9898, float(seed) + 78.233))) * 43758.5453);
                return r;
            }

            float SmoothLerp(float min, float max, float t) 
            {
                t = t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
                return min + t * (max - min);
            }

            float HashGrid(int seed, int i, int j)
            {
                float r = WhiteNoise(seed, i, j);
                r = r * 2.0f - 1.0f;
                return r;
            }

            float2 ComputeGradient(int seed, int gridX, int gridY)
            {
                float2 gradient = float2(HashGrid(seed * 123 + 345, gridX, gridY), HashGrid(seed * 456 + 234, gridX, gridY));
                return normalize(gradient);
            }

            float PerlinNoiseTiling(int seed, float2 p, float gridSize, int tilingSize)
            {
                p /= gridSize;
                int gridX = floor(p.x);
                int gridY = floor(p.y);
                int gridXP1 = (gridX + 1);
                int gridYP1 = (gridY + 1);
                
                float2 gradient00 = ComputeGradient(seed, gridX % tilingSize, gridY % tilingSize);
                float2 gradient01 = ComputeGradient(seed, gridX % tilingSize, gridYP1 % tilingSize );
                float2 gradient10 = ComputeGradient(seed, gridXP1 % tilingSize, gridY % tilingSize);
                float2 gradient11 = ComputeGradient(seed, gridXP1 % tilingSize , gridYP1 % tilingSize);

                float2 v00 = float2(gridX, gridY);
                float2 v01 = float2(gridX, gridYP1);
                float2 v10 = float2(gridXP1, gridY);
                float2 v11 = float2(gridXP1, gridYP1);

                float dp00 = dot((p - v00), gradient00);
                float dp01 = dot((p - v01), gradient01);
                float dp10 = dot((p - v10), gradient10);
                float dp11 = dot((p - v11), gradient11);

                float tx = (p.x - v00.x);
                float ty = (p.y - v00.y);
                float res = SmoothLerp(SmoothLerp(dp00, dp10, tx), SmoothLerp(dp01, dp11, tx), ty);

                return res;
            }

            float PerlinNoiseTilingFBM6(int seed, float2 p, float gridSize)
            {
                float2x2 mat = { 
                                0.8f, 0.6f,
                                -0.6f, 0.8f
                            };

                float f = 0.0f;
                int numFbmSteps = 6;
                float multiplier[6] = { 2.02f, 2.03f, 2.01f, 2.04f, 2.01f, 2.02f };
                float amp = 1.0f;
                for (int i = 0; i < numFbmSteps; ++i)
                {
                    f += amp * PerlinNoiseTiling(seed, p, gridSize, 10);
                    p = mul(mat, p) * multiplier[i];
                    amp *= 0.5f;
                }
                return f / 0.96875f;
            }

            fixed4 frag (v2f pixel) : SV_Target
            {
                float fireHeight = 0.5f;
                float mask = fireHeight - 2.0f * pow(pixel.uv.y, 2.0f);
                mask -= 1.5f * pow((abs(2.0f * (pixel.uv.x - 0.5f) )), 2.0f) ;

                float noise = PerlinNoiseTilingFBM6(48, (pixel.uv + float2(0, -_Time.y)), 0.15f);
                mask += saturate(pixel.uv.y + 0.3f) * noise;

                mask *= 1.5f;
                float detailMask = mask;
                float3 albedo = float3(1.5f, 1.2f, 1.0f) * float3(detailMask, pow(detailMask, 2.0f), pow(detailMask, 3.0f));
                float3 res = saturate(albedo) * saturate(mask * 10.0f);

                return fixed4(res, 1.0f);
            }
            ENDCG
        }
    }
}

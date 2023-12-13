Shader "Hidden/DirectionalBuffer"
{
    Properties
    {

    }
    SubShader
    {
        Tags
        {
            "LightMode" = "ForwardBase"
            "IgnoreProjector" = "True"
            "DisableBatching" = "LODFading"
        }

        Cull Back
        //ZTest Always
        //ZWrite On

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uvStaticLightmap : TEXCOORD1;
            };

            v2f vert(appdata_full v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uvStaticLightmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //note: due to unity stripping... we have to sample the regular lightmap before we can actually sample the directional lightmap... so deal with it
                #if defined(LIGHTMAP_ON) && (DIRLIGHTMAP_COMBINED)
                    float2 lightmapUVs = i.uvStaticLightmap.xy;
                    float4 indirectLightmap = UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUVs.xy);
                    float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, lightmapUVs);
                    lightmapDirection += indirectLightmap * 0.000001f;
                    //lightmapDirection.rgb *= lightmapDirection.a;

                    return float4(lightmapDirection.rgb, 1.0f);
                #else
                    float3 sphericalHarmonicsDirection = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz + unity_SHBr.xyz + unity_SHBg.xyz + unity_SHBb.xyz + unity_SHC.xyz;
                    sphericalHarmonicsDirection = normalize(sphericalHarmonicsDirection);

                    return float4(sphericalHarmonicsDirection, 1.0f);
                #endif
            }
            ENDCG
        }
    }
    //Fallback "VertexLit"
}

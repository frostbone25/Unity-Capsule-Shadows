Shader "Hidden/MaskBuffer"
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
            };

            v2f vert(appdata_full v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                #if defined(LIGHTMAP_ON) && (DIRLIGHTMAP_COMBINED)
                    return float4(0.0f, 0.0f, 0.0f, 0.0f);
                #else
                    return float4(1.0f, 0.0f, 0.0f, 1.0f);
                #endif
            }
            ENDCG
        }
    }
    //Fallback "VertexLit"
}

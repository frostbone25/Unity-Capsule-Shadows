Shader "Hidden/AnalyticalShadowsBufferV1"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//||||||||||||||||||||||||||||||||| PASS 0: COMBINE RESULT |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 0: COMBINE RESULT |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 0: COMBINE RESULT |||||||||||||||||||||||||||||||||
		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
			sampler2D _MaskBuffer;
			sampler2D _ComputeShaderResult;
			float4 _ComputeShaderResult_TexelSize;
			float _Intensity;
			float _SelfShadowIntensity;
			float _MaxIntensityClamp;

			struct NewAttributesDefault
			{
				float3 vertex : POSITION;
				float4 texcoord : TEXCOORD;
			};

			struct Varyings
			{
				float4 vertex : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 texcoordStereo : TEXCOORD1;

				#if STEREO_INSTANCING_ENABLED
					uint stereoTargetEyeIndex : SV_RenderTargetArrayIndex;
				#endif
			};

			Varyings Vert(NewAttributesDefault v)
			{
				Varyings o;

				o.vertex = float4(v.vertex.xy, 0.0, 1.0);
				o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);

				#if UNITY_UV_STARTS_AT_TOP
					o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
				#endif

				o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);

				return o;
			}

			float4 Frag(Varyings i) : SV_Target
			{
				float2 uv = i.texcoordStereo.xy;
				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
				float result = tex2D(_ComputeShaderResult, uv).r;
				//float mask = saturate(tex2D(_MaskBuffer, uv).r);
				//float4 result = tex2D(_ComputeShaderResult, uv);
				float4 mask = tex2D(_MaskBuffer, uv);

				//result = lerp(result, 1.0f, mask * _SelfShadowIntensity);
				//result = lerp(result, 1.0f, lerp(mask, 0.0f, _SelfShadowIntensity));
				result = lerp(1.0f, result, _Intensity);
				result = saturate(result) * _MaxIntensityClamp + (1 - _MaxIntensityClamp);

				return color * result;
				//return result;
			}

			ENDHLSL
		}

		//||||||||||||||||||||||||||||||||| PASS 1: DOWNSAMPLE RESULT |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 1: DOWNSAMPLE RESULT |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 1: DOWNSAMPLE RESULT |||||||||||||||||||||||||||||||||
		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment Frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			sampler2D _ComputeShaderResult;
			float4 _ComputeShaderResult_TexelSize;

			struct NewAttributesDefault
			{
				float3 vertex : POSITION;
				float4 texcoord : TEXCOORD;
			};

			struct Varyings
			{
				float4 vertex : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 texcoordStereo : TEXCOORD1;

				#if STEREO_INSTANCING_ENABLED
					uint stereoTargetEyeIndex : SV_RenderTargetArrayIndex;
				#endif
			};

			Varyings Vert(NewAttributesDefault v)
			{
				Varyings o;

				o.vertex = float4(v.vertex.xy, 0.0, 1.0);
				o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);

				#if UNITY_UV_STARTS_AT_TOP
					o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
				#endif

				o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);

				return o;
			}

			float4 Frag(Varyings i) : SV_Target
			{
				float2 uv = i.texcoordStereo.xy;

				float result = 0.0;
				result += tex2D(_ComputeShaderResult, uv + float2(_ComputeShaderResult_TexelSize.x, 0)).r;
				result += tex2D(_ComputeShaderResult, uv + float2(-_ComputeShaderResult_TexelSize.x, 0)).r;
				result += tex2D(_ComputeShaderResult, uv + float2(0, _ComputeShaderResult_TexelSize.y)).r;
				result += tex2D(_ComputeShaderResult, uv + float2(0, -_ComputeShaderResult_TexelSize.y)).r;
				result *= 0.25;

				return float4(result, 0, 0, 1);
			}

			ENDHLSL
		}

		//||||||||||||||||||||||||||||||||| PASS 2: BILATERIAL BLUR H |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 2: BILATERIAL BLUR H |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 2: BILATERIAL BLUR H |||||||||||||||||||||||||||||||||
		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment FragBlur
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_local _ BLUR_HIGH_QUALITY
			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			//#define BLUR_HIGH_QUALITY
			#define BLUR_HORIZONTAL

			#include "BilateralBlur.hlsl"
			ENDHLSL
		}

		//||||||||||||||||||||||||||||||||| PASS 3: BILATERIAL BLUR V |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 3: BILATERIAL BLUR V |||||||||||||||||||||||||||||||||
		//||||||||||||||||||||||||||||||||| PASS 3: BILATERIAL BLUR V |||||||||||||||||||||||||||||||||
		Pass
		{
			HLSLPROGRAM
			#pragma vertex Vert
			#pragma fragment FragBlur
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_local _ BLUR_HIGH_QUALITY
			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			//#define BLUR_HIGH_QUALITY
			//#define BLUR_HORIZONTAL

			#include "BilateralBlur.hlsl"
			ENDHLSL
		}
	}
}

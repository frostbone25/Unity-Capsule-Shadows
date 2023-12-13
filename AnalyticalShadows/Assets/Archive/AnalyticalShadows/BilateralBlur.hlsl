/*
* SELF NOTE:
* Basically this is the Bilateral Blur used for the Scalable AO included in the Unity Post Processing package.
*/

TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);

sampler2D _RenderTarget;
float4 _RenderTarget_TexelSize;
int _DownsampleFactor;
float kGeometryCoeff;

float3 SampleNormal(float2 uv)
{
	float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
	return DecodeViewNormalStereo(cdn) * float3(1.0, 1.0, -1.0);
}

// Normal vector comparer (for geometry-aware weighting)
half CompareNormal(half3 d1, half3 d2)
{
	return smoothstep(kGeometryCoeff, 1.0, dot(d1, d2));
}

// Geometry-aware bilateral filter (single pass/small kernel)
half BlurSmall(TEXTURE2D_ARGS(tex, samp), float2 uv, float2 delta)
{
	half p0 = SAMPLE_TEXTURE2D(tex, samp, UnityStereoTransformScreenSpaceTex(uv)).r;
	half p1 = SAMPLE_TEXTURE2D(tex, samp, UnityStereoTransformScreenSpaceTex(uv + float2(-delta.x, -delta.y))).r;
	half p2 = SAMPLE_TEXTURE2D(tex, samp, UnityStereoTransformScreenSpaceTex(uv + float2(delta.x, -delta.y))).r;
	half p3 = SAMPLE_TEXTURE2D(tex, samp, UnityStereoTransformScreenSpaceTex(uv + float2(-delta.x, delta.y))).r;
	half p4 = SAMPLE_TEXTURE2D(tex, samp, UnityStereoTransformScreenSpaceTex(uv + float2(delta.x, delta.y))).r;

	half3 n0 = SampleNormal(uv);
	half3 n1 = SampleNormal(UnityStereoTransformScreenSpaceTex(uv + float2(-delta.x, -delta.y)));
	half3 n2 = SampleNormal(UnityStereoTransformScreenSpaceTex(uv + float2(delta.x, -delta.y)));
	half3 n3 = SampleNormal(UnityStereoTransformScreenSpaceTex(uv + float2(-delta.x, delta.y)));
	half3 n4 = SampleNormal(UnityStereoTransformScreenSpaceTex(uv + float2(delta.x, delta.y)));

	half w0 = 1.0;
	half w1 = CompareNormal(n0, n1);
	half w2 = CompareNormal(n0, n2);
	half w3 = CompareNormal(n0, n3);
	half w4 = CompareNormal(n0, n4);

	half s;
	s = p0 * w0;
	s += p1 * w1;
	s += p2 * w2;
	s += p3 * w3;
	s += p4 * w4;

	return s / (w0 + w1 + w2 + w3 + w4);
}

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

// Geometry-aware separable bilateral filter
float4 FragBlur(VaryingsDefault i) : SV_Target
{
	#if defined(BLUR_HORIZONTAL)
		// Horizontal pass: Always use 2 texels interval to match to
		// the dither pattern.
		float2 delta = float2(_RenderTarget_TexelSize.x * _DownsampleFactor, 0.0);
		//float2 delta = float2(TEXEL_OFFSET_MULTIPLIER, 0.0);
	#else
		// Vertical pass: Apply _Downsample to match to the dither
		// pattern in the original occlusion buffer.
		//float2 delta = float2(0.0, _RenderTarget_TexelSize.y / DOWNSAMPLE * 2.0);
		float2 delta = float2(0.0, _RenderTarget_TexelSize.y * _DownsampleFactor);
		//float2 delta = float2(0.0, TEXEL_OFFSET_MULTIPLIER);
	#endif

	#if defined(BLUR_HIGH_QUALITY) // High quality 7-tap Gaussian with adaptive sampling
		half p0 = tex2D(_RenderTarget, i.texcoordStereo).r;
		half p1a = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord - delta)).r;
		half p1b = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord + delta)).r;
		half p2a = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 2.0)).r;
		half p2b = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 2.0)).r;
		half p3a = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 3.2307692308)).r;
		half p3b = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 3.2307692308)).r;

		half3 n0 = SampleNormal(i.texcoordStereo);
		half3 n1a = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord - delta));
		half3 n1b = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord + delta));
		half3 n2a = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 2.0));
		half3 n2b = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 2.0));
		half3 n3a = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 3.2307692308));
		half3 n3b = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 3.2307692308));

		half w0 = 0.37004405286;
		half w1a = CompareNormal(n0, n1a) * 0.31718061674;
		half w1b = CompareNormal(n0, n1b) * 0.31718061674;
		half w2a = CompareNormal(n0, n2a) * 0.19823788546;
		half w2b = CompareNormal(n0, n2b) * 0.19823788546;
		half w3a = CompareNormal(n0, n3a) * 0.11453744493;
		half w3b = CompareNormal(n0, n3b) * 0.11453744493;

		half s;
		s = p0 * w0;
		s += p1a * w1a;
		s += p1b * w1b;
		s += p2a * w2a;
		s += p2b * w2b;
		s += p3a * w3a;
		s += p3b * w3b;

		s /= w0 + w1a + w1b + w2a + w2b + w3a + w3b;

	#else
		// Fater 5-tap Gaussian with linear sampling
		half p0 = tex2D(_RenderTarget, i.texcoordStereo).r;
		half p1a = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 1.3846153846)).r;
		half p1b = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 1.3846153846)).r;
		half p2a = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 3.2307692308)).r;
		half p2b = tex2D(_RenderTarget, UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 3.2307692308)).r;

		half3 n0 = SampleNormal(i.texcoordStereo);
		half3 n1a = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 1.3846153846));
		half3 n1b = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 1.3846153846));
		half3 n2a = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord - delta * 3.2307692308));
		half3 n2b = SampleNormal(UnityStereoTransformScreenSpaceTex(i.texcoord + delta * 3.2307692308));

		half w0 = 0.2270270270;
		half w1a = CompareNormal(n0, n1a) * 0.3162162162;
		half w1b = CompareNormal(n0, n1b) * 0.3162162162;
		half w2a = CompareNormal(n0, n2a) * 0.0702702703;
		half w2b = CompareNormal(n0, n2b) * 0.0702702703;

		half s;
		s = p0 * w0;
		s += p1a * w1a;
		s += p1b * w1b;
		s += p2a * w2a;
		s += p2b * w2b;

		s /= w0 + w1a + w1b + w2a + w2b;
	#endif

	return float4(s, s, s, 1);
}
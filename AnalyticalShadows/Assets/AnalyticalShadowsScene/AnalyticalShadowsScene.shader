Shader "ScenePostProcessing/AnalyticalShadowsScene"
{
    Properties
    {
        [Header(Rendering)]
        [KeywordEnum(FromCameraDepth, FromCameraDepthNormals)] _DepthType("Depth Type", Float) = 0
        [KeywordEnum(GlobalDirection, LightProbes)] _DirectionType("Direction Type", Float) = 0
        [Toggle(SIMPLIFY_LIGHT_PROBE_DIRECTION)] _SimplifyLightProbeDirection("Simplify Light Probe Direction", Float) = 1
        _GlobalDirection("Global Direction", Vector) = (0, 1, 0, 0)
        _ConeAngle("Cone Angle", Range(1, 90)) = 45
        _Intensity("Intensity", Float) = 1
        [KeywordEnum(Sphere, Capsule)] _CasterType("Caster Type", Float) = 0

        [Header(Sphere Caster)]
        _SphereRadius("Sphere Radius", Float) = 1

        [Header(Capsule Caster)]
        _CapsuleDirection("Capsule Direction", Vector) = (1, 0, 0, 0)
        _CapsuleHeight("Capsule Height", Float) = 2
        _CapsuleRadius("Capsule Radius", Float) = 1
    }
    SubShader
    {
        Tags 
        { 
            "LightMode" = "ForwardBase"
            "RenderType" = "Opaque" 
            "Queue" = "Transparent+2000"
        }

        Cull Off
        ZWrite Off
        ZTest Off

        Blend DstColor Zero // Multiplicative

        Pass
        {
            CGPROGRAM
            #pragma vertex vertex_base
            #pragma fragment fragment_base

            #pragma multi_compile_instancing

            #pragma multi_compile _CASTERTYPE_SPHERE _CASTERTYPE_CAPSULE
            #pragma multi_compile _DEPTHTYPE_FROMCAMERADEPTH _DEPTHTYPE_FROMCAMERADEPTHNORMALS
            #pragma multi_compile _DIRECTIONTYPE_GLOBALDIRECTION _DIRECTIONTYPE_LIGHTPROBES

            #pragma shader_feature_local SIMPLIFY_LIGHT_PROBE_DIRECTION

            #include "UnityCG.cginc"
            #include "AnalyticalShadowsCommonScene.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthNormalsTexture);
            float4 _CameraDepthNormalsTexture_TexelSize;

            float _SphereRadius;

            float3 _CapsuleDirection;
            float _CapsuleHeight;
            float _CapsuleRadius;

            float3 _GlobalDirection;
            float _ConeAngle;
            float _Intensity;

            /*
                ref: https://developer.amd.com/wordpress/media/2012/10/Oat-AmbientApetureLighting.pdf
                Approximate the area of intersection of two spherical caps.

                With some modifcations proposed by the shadertoy implementation
            */
            float SphericalCapsIntersectionAreaFast(float cosCap1, float cosCap2, float cap2, float cosDistance)
            {
                // Constants
                const float EPSILON = 0.0001;

                // Precompute constants
                float radius1 = acosFastPositive(cosCap1); // First caps radius (arc length in radians)
                float radius2 = cap2; // Second caps radius (in radians)
                float dist = acosFast(cosDistance); // Distance between caps (radians between centers of caps)

                // Conditional expressions instead of if-else
                float check1 = min(radius1, radius2) <= max(radius1, radius2) - dist;
                float check2 = radius1 + radius2 <= dist;

                // Ternary operator to replace if-else
                float result = check1 ? (1.0 - max(cosCap1, cosCap2)) : (check2 ? 0.0 : 1.0 - max(cosCap1, cosCap2));

                float delta = abs(radius1 - radius2);
                float x = 1.0 - saturate((dist - delta) / max(radius1 + radius2 - delta, EPSILON));

                // simplified smoothstep()
                float area = sq(x) * (-2.0 * x + 3.0);

                // Multiply by (1.0 - max(cosCap1, cosCap2)) only once
                return area * result;
            }

            float directionalOcclusionSphere(float3 rayPosition, float3 spherePosition, float sphereRadius, float4 coneProperties)
            {
                float3 occluderPosition = spherePosition.xyz - rayPosition;
                float occluderLength2 = dot(occluderPosition, occluderPosition);
                float3 occluderDir = occluderPosition * rsqrt(occluderLength2);

                float cosPhi = dot(occluderDir, coneProperties.xyz);
                // sq(sphere.w) should be a uniform --> capsuleRadius^2
                float cosTheta = sqrt(occluderLength2 / (sq(sphereRadius) + occluderLength2));
                float cosCone = cos(coneProperties.w);

                return 1.0 - SphericalCapsIntersectionAreaFast(cosTheta, cosCone, coneProperties.w, cosPhi) / (1.0 - cosCone);
            }

            float directionalOcclusionCapsule(float3 rayPosition, float3 capsuleA, float3 capsuleB, float capsuleRadius, float4 coneProperties)
            {
                float3 Ld = capsuleB - capsuleA;
                float3 L0 = capsuleA - rayPosition;
                float a = dot(coneProperties.xyz, Ld);
                float t = saturate(dot(L0, a * coneProperties.xyz - Ld) / (dot(Ld, Ld) - a * a));
                float3 positionToRay = capsuleA + t * Ld;

                return directionalOcclusionSphere(rayPosition, positionToRay, capsuleRadius, coneProperties);
            }

            float3 GetDominantSphericalHarmoncsDirection()
            {
                //add the L1 bands from the spherical harmonics probe to get our direction.
                float3 sphericalHarmonics_dominantDirection = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;

                #if defined (SIMPLIFY_LIGHT_PROBE_DIRECTION)
                    sphericalHarmonics_dominantDirection += unity_SHBr.xyz + unity_SHBg.xyz + unity_SHBb.xyz + unity_SHC; //add the L2 bands for better precision
                #endif

                sphericalHarmonics_dominantDirection = normalize(sphericalHarmonics_dominantDirection);

                return sphericalHarmonics_dominantDirection;
            }

            float4 GetConeProperties()
            {
                #if defined (_DIRECTIONTYPE_GLOBALDIRECTION)
                    float4 cone = float4(normalize(_GlobalDirection.xyz), radians(_ConeAngle) * 0.5);
                #elif defined (_DIRECTIONTYPE_LIGHTPROBES)
                    float4 cone = float4(GetDominantSphericalHarmoncsDirection(), radians(_ConeAngle) * 0.5);
                #endif

                return cone;
            }

            struct meshData
            {
                float4 vertex : POSITION;

                //Single Pass Instanced Support
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertexToFragment
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 camRelativeWorldPos : TEXCOORD1;
                float3 objectOrigin : TEXCOORD2;
                float3 capsuleDirection : TEXCOORD3;

                //Single Pass Instanced Support
                UNITY_VERTEX_OUTPUT_STEREO
            };

            vertexToFragment vertex_base(meshData v)
            {
                vertexToFragment o;

                //Single Pass Instanced Support
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(vertexToFragment, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = UnityStereoTransformScreenSpaceTex(ComputeScreenPos(o.vertex));
                o.camRelativeWorldPos = mul(unity_ObjectToWorld, fixed4(v.vertex.xyz, 1.0)).xyz - _WorldSpaceCameraPos;

                o.objectOrigin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;

                #if defined (_CASTERTYPE_CAPSULE)
                    o.capsuleDirection = normalize(mul(unity_ObjectToWorld, _CapsuleDirection).xyz);
                #else
                    o.capsuleDirection = float3(0, 0, 0);
                #endif

                return o;
            }

            float SampleDepth(float2 uv)
            {
                #if defined (_DEPTHTYPE_FROMCAMERADEPTH)
                    float4 rawCameraDepthTexture = tex2D(_CameraDepthTexture, uv);
                    return rawCameraDepthTexture.r;
                #elif defined (_DEPTHTYPE_FROMCAMERADEPTHNORMALS)
                    float4 rawCameraDepthNormalsTexture = tex2D(_CameraDepthNormalsTexture, uv);

                    float decodedFloat = DecodeFloatRG(rawCameraDepthNormalsTexture.zw);
                    decodedFloat = Linear01Depth(decodedFloat);

                    return decodedFloat;
                #endif
            }

            float4 fragment_base(vertexToFragment i) : SV_Target
            {
                //Single Pass Instanced Support
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;

                #if UNITY_UV_STARTS_AT_TOP
                    if (_CameraDepthTexture_TexelSize.y < 0)
                        screenUV.y = 1 - screenUV.y;
                #endif

                #if UNITY_SINGLE_PASS_STEREO
                    // If Single-Pass Stereo mode is active, transform the
                    // coordinates to get the correct output UV for the current eye.
                    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
                    screenUV = (screenUV - scaleOffset.zw) / scaleOffset.xy;
                #endif

                float rawDepth = SampleDepth(screenUV);
                float linearDepth = LinearEyeDepth(rawDepth);
                float3 cameraWorldPositionViewPlane = i.camRelativeWorldPos.xyz / dot(i.camRelativeWorldPos.xyz, unity_WorldToCamera._m20_m21_m22);
                float3 computedWorldPosition = cameraWorldPositionViewPlane * linearDepth + _WorldSpaceCameraPos;

                float result = 1;

                float4 cone = GetConeProperties();

                #if defined (_CASTERTYPE_SPHERE)
                    result *= directionalOcclusionSphere(computedWorldPosition, i.objectOrigin, _SphereRadius, cone);
                #elif defined (_CASTERTYPE_CAPSULE)
                    float3 endA = i.objectOrigin + i.capsuleDirection * (_CapsuleHeight * 0.5);
                    float3 endB = i.objectOrigin - i.capsuleDirection * (_CapsuleHeight * 0.5);

                    result *= directionalOcclusionCapsule(computedWorldPosition, endA, endB, _CapsuleRadius, cone);
                #endif

                result = lerp(1.0f, result, _Intensity);

                return result;
            }
            ENDCG
        }
    }
}

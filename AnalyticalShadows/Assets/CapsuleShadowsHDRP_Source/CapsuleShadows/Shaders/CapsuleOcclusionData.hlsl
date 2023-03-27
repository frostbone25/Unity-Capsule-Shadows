#ifndef CAPSULE_OCCLUSION_DATA
#define CAPSULE_OCCLUSION_DATA
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/EllipsoidOccluder.cs.hlsl"


// --------------------------------------------
// Shader variables
// --------------------------------------------
CBUFFER_START(CapsuleOcclusionConstantBuffer)
float4 _CapsuleShadowParameters;    // xyz: direction w: cone width to use.      // Soon to be subjected to changes!
float4 _CapsuleShadowParameters2; 
float4 _CapsuleOcclusionIntensities;
CBUFFER_END

#define _CapsuleAmbientOcclusionIntensity _CapsuleOcclusionIntensities.x 
#define _CapsuleSpecularOcclusionIntensity _CapsuleOcclusionIntensities.y
#define _CapsuleShadowIntensity saturate(_CapsuleOcclusionIntensities.z)
#define _CapsuleShadowIsPunctual (_CapsuleShadowParameters2.x == 0)

TEXTURE3D(_CapsuleShadowLUT);


// StructuredBuffer<OrientedBBox> _CapsuleOccludersBounds;
StructuredBuffer<EllipsoidOccluderData> _CapsuleOccludersDatas;

EllipsoidOccluderData FetchEllipsoidOccluderData(uint index)
{
    return _CapsuleOccludersDatas[index];
}

// --------------------------------------------
// Occluder data helpers
// --------------------------------------------
float3 GetOccluderPositionRWS(EllipsoidOccluderData data)
{
    return data.positionRWS_radius.xyz;
}

float GetOccluderRadius(EllipsoidOccluderData data)
{
    return data.positionRWS_radius.w;
}

float3 GetOccluderDirectionWS(EllipsoidOccluderData data)
{
    return normalize(data.directionWS_influence.xyz);
}

float GetOccluderScaling(EllipsoidOccluderData data)
{
    return length(data.directionWS_influence.xyz);
}

float GetOccluderInfluenceRadiusWS(EllipsoidOccluderData data)
{
    return data.directionWS_influence.w;
}


// --------------------------------------------
// Data preparation functions
// --------------------------------------------
// Returns pos/radius of occluder as sphere relative to positionWS
float3 TransformOccluder(EllipsoidOccluderData data, float3 positionWS)
{
    float3 dir = GetOccluderDirectionWS(data);
    float3 toOccluder = GetOccluderPositionRWS(data) - positionWS;
    float proj = dot(toOccluder, dir);
    float3 toOccluderCS = toOccluder - (proj * dir) + proj * dir / GetOccluderScaling(data);
    return float3(toOccluderCS);
}

float4 GetDataForSphereIntersection(EllipsoidOccluderData data, float3 positionWS)
{
    // TODO : Fill with transformations needed so the rest of the code deals with simple spheres.
    // xyz should be un-normalized direction, w should contain the length.
    float3 dir = TransformOccluder (data, positionWS); 
    float len = length(dir);
    dir = normalize(dir);
    return float4(dir.x, dir.y, dir.z, len);
}

void ComputeDirectionAndDistanceFromStartAndEnd(float3 start, float3 end, out float3 direction, out float dist)
{
    direction = end - start;
    dist = length(direction);
    direction = (dist > 1e-5f) ? (direction / dist) : float3(0.0f, 1.0f, 0.0f);
}

float ComputeInfluenceFalloff(float dist, float influenceRadius)
{
    return smoothstep(1.0f, 0.75f, dist / influenceRadius);
}

float ApplyInfluenceFalloff(float occlusion, float influenceFalloff)
{
    return lerp(1.0f, occlusion, influenceFalloff);
}

float3 TransformDirection(float3 direction, EllipsoidOccluderData data)
{
    float3 dir = GetOccluderDirectionWS(data);
    float proj = dot(direction, dir);
    return direction - (proj * dir) + proj * dir / GetOccluderScaling(data);
}

#endif

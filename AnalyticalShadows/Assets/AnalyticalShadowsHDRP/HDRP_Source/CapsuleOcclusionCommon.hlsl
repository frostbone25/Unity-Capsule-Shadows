#ifndef CAPSULE_OCCLUSION_COMMON_DEF
#define CAPSULE_OCCLUSION_COMMON_DEF

#if !defined(USE_FPTL_LIGHTLIST) && !defined(USE_CLUSTERED_LIGHTLIST)
    #define USE_FPTL_LIGHTLIST // Use light tiles for contact shadows
#endif
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/CapsuleOcclusionSystem.cs.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/Shaders/CapsuleOcclusionData.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/Shaders/CapsuleOcclusionShaderUtils.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoopDef.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows/Shaders/CapsuleSGSpecularOcclusion.hlsl"

// --------------------------------------------
// Evaluation functions
// --------------------------------------------
// These functions should evaluate the occlusion types. Note that all of these functions take EllipsoidOccluderData containing the shape to evaluate against
// and a dirAndLength containing the data output by the function GetDataForSphereIntersection()

float EvaluateCapsuleAmbientOcclusion(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    // TODO: Can combine distance falloff math with IQSphereAO math.
    float3 occluderFromSurfaceDirectionWS;
    float occluderFromSurfaceDistance;
    ComputeDirectionAndDistanceFromStartAndEnd(positionWS, GetOccluderPositionRWS(data), occluderFromSurfaceDirectionWS, occluderFromSurfaceDistance);

    float3 occluder = TransformOccluder(data, positionWS);
    float occlusion = 1.0f - IQSphereAO(0, N, occluder.xyz, GetOccluderRadius(data));
    occlusion = ApplyInfluenceFalloff(occlusion, ComputeInfluenceFalloff(occluderFromSurfaceDistance, GetOccluderInfluenceRadiusWS(data)));

    return 1.0f - occlusion;
}

// I stubbed out this version as a reference for myself while the work was being done by others. Keeping here as a reference in case we need it,
// but leaving the above version as the standard so that I do not interfere with others work.
float EvaluateCapsuleAmbientOcclusionNick(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    // TODO: Can combine distance falloff math with IQSphereAO math.
    float3 occluderFromSurfaceDirectionWS;
    float occluderFromSurfaceDistance;
    ComputeDirectionAndDistanceFromStartAndEnd(positionWS, GetOccluderPositionRWS(data), occluderFromSurfaceDirectionWS, occluderFromSurfaceDistance);

    float occluderSphereRadius = GetOccluderRadius(data) * 0.9;
    float occlusion = 1.0f - IQSphereAO(positionWS, N, GetOccluderPositionRWS(data), occluderSphereRadius);
    occlusion = ApplyInfluenceFalloff(occlusion, ComputeInfluenceFalloff(occluderFromSurfaceDistance, GetOccluderInfluenceRadiusWS(data)));

    return occlusion;
}

float EvaluateCapsuleSpecularOcclusion(EllipsoidOccluderData data, float3 positionWS, float3 N, float3 V, float roughness, float4 dirAndLength)
{
    // return EvaluateCapsuleAmbientOcclusionSphericalGaussianReference(data, positionWS, N, V, roughness, dirAndLength);
    // return EvaluateCapsuleAmbientOcclusion(data, positionWS, N, dirAndLength);
#if 0
    return EvaluateCapsuleSpecularOcclusionSGOccluderSGBRDF(data, positionWS, N, V, roughness, dirAndLength);
#elif 1
    return EvaluateCapsuleSpecularOcclusionASGOccluderSGBRDF(data, positionWS, N, V, roughness, dirAndLength);
#elif 0
    return EvaluateCapsuleSpecularOcclusionSGOccluderASGBRDF(data, positionWS, N, V, roughness, dirAndLength);
#elif 0
    return EvaluateCapsuleSpecularOcclusionASGOccluderASGBRDF(data, positionWS, N, V, roughness, dirAndLength);
#elif 0
    return EvaluateCapsuleAmbientOcclusionSphericalGaussianReference(data, positionWS, N, V, roughness, dirAndLength);
#endif
}

// https://graphics.pixar.com/library/OrthonormalB/paper.pdf
void GetOrthoBasis(float3 normal, out float3 tangent, out float3 bitangent)
{
    float normalSign = (normal.z >= 0.0f) ? 1.0f : -1.0f; // == copysignf(normal.z) in reference
    float a = rcp(-normalSign - normal.z); // == -1.0f / (normalSign + normal.z) in reference
    float b = normal.x * normal.y * a;
    tangent = float3(1.0f + normalSign * normal.x * normal.x * a, normalSign * b, -normalSign * normal.x);
    bitangent = float3(b, normalSign + normal.y * normal.y * a, -normal.y);
}


// Ref https://developer.amd.com/wordpress/media/2012/10/Oat-AmbientApetureLighting.pdf
// Quite slow... 
float EvaluateCapsuleShadowAnalytical(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    float3 coneAxis = _CapsuleShadowParameters.xyz;

    if (_CapsuleShadowIsPunctual)
    {
        float3 lightPos = _CapsuleShadowParameters.xyz;
        coneAxis = normalize(lightPos - positionWS);
    }

    float radius = GetOccluderRadius(data);
    float4 dirAndLen = GetDataForSphereIntersection(data, positionWS);
    
    float3 occluderFromSurfaceDirectionOS = dirAndLen.xyz;
    float occluderFromSurfaceDistance = dirAndLen.w;

    float3 coneAxisOS = TransformDirection (coneAxis, data);
    float cosPhi = dot(coneAxisOS, occluderFromSurfaceDirectionOS);
    
    float tanTheta = radius / occluderFromSurfaceDistance;
    float theta = FastATanPos(tanTheta);

    // TODO: unified the below code with the analytical version.
    float lightAngle = _CapsuleShadowParameters.w; // get from code.
    float phi = FastACos(cosPhi);

    float intersectionArea = 0;
    float minRadius = min(lightAngle, theta);
    float maxRadius = max(lightAngle, theta);

    if (phi <= (maxRadius - minRadius))
    {
        intersectionArea = TWO_PI - TWO_PI * cos(minRadius);
    }
    else if (phi >= (theta + lightAngle))
    {
        intersectionArea = 0;
    }
    else
    {
        float diff = abs(theta - lightAngle);
        intersectionArea = smoothstep(0.0f, 1.0f, 1.0f - saturate((phi - diff) / (theta + lightAngle - diff)));
        intersectionArea *= (TWO_PI - TWO_PI * cos(minRadius));
    }

    float lightArea = TWO_PI - TWO_PI * cos(lightAngle);
    float NdotPosToSphere = dot(N, occluderFromSurfaceDirectionOS);

    float occlusion = 1.0f - saturate(intersectionArea / lightArea);
    return ApplyInfluenceFalloff(occlusion, ComputeInfluenceFalloff(length(GetOccluderPositionRWS(data) - positionWS), GetOccluderInfluenceRadiusWS(data)));
}


float EvaluateCapsuleShadowAnalytical2(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    float3 coneAxis = _CapsuleShadowParameters.xyz;

    if (_CapsuleShadowIsPunctual)
    {
        float3 lightPos = _CapsuleShadowParameters.xyz;
        coneAxis = normalize(lightPos - positionWS);
    }

    float radius = GetOccluderRadius(data);
    float3 occluderPosWS = GetOccluderPositionRWS(data);

    float3 basisX, basisY;
    float3 basisZ = GetOccluderDirectionWS(data);
    GetOrthoBasis(basisZ, basisX, basisY);
    basisZ *= (radius / ((.5f * GetOccluderScaling(data) * GetOccluderRadius(data)) + radius));

    float3 sphereToPos = positionWS - occluderPosWS;
    sphereToPos = float3(dot(sphereToPos, basisX), dot(sphereToPos, basisY), dot(sphereToPos, basisZ));

    coneAxis = float3(dot(coneAxis, basisX), dot(coneAxis, basisY), dot(coneAxis, basisZ));

    float sphereToPosLen = length(sphereToPos);
    sphereToPos = -sphereToPos / sphereToPosLen;
    coneAxis = normalize(coneAxis);

    float phi = acos(dot(sphereToPos, coneAxis));
    float theta = FastATanPos(radius / sphereToPosLen);

    // TODO: unified the below code with the analytical version.
    float lightAngle = _CapsuleShadowParameters.w; // get from code.

    float intersectionArea = 0;
    float minRadius = min(lightAngle, theta);
    float maxRadius = max(lightAngle, theta);

    if (phi <= (maxRadius - minRadius))
    {
        intersectionArea = TWO_PI - TWO_PI * cos(minRadius);
    }
    else if (phi >= (theta + lightAngle))
    {
        intersectionArea = 0;
    }
    else
    {
        float diff = abs(theta - lightAngle);
        intersectionArea = smoothstep(0.0f, 1.0f, 1.0f - saturate((phi - diff) / (theta + lightAngle - diff)));
        intersectionArea *= (TWO_PI - TWO_PI * cos(minRadius));
    }

    float lightArea = TWO_PI - TWO_PI * cos(lightAngle);

    float occlusion = 1.0f - saturate(intersectionArea / lightArea);
    float occluderFromSurfaceDistance = length(occluderPosWS - positionWS);
    return ApplyInfluenceFalloff(occlusion, ComputeInfluenceFalloff(occluderFromSurfaceDistance, GetOccluderInfluenceRadiusWS(data)));
}


float EvaluateCapsuleShadowLUT2(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    // For now assuming just directional light.
    float3 coneAxis = _CapsuleShadowParameters.xyz;

    if (_CapsuleShadowIsPunctual)
    {
        float3 lightPos = _CapsuleShadowParameters.xyz;
        coneAxis = normalize(lightPos - positionWS);
    }

    float radius = GetOccluderRadius(data);
    float4 dirAndLen = GetDataForSphereIntersection(data, positionWS);

    float3 occluderFromSurfaceDirectionOS = dirAndLen.xyz;
    float occluderFromSurfaceDistance = dirAndLen.w;
    ComputeDirectionAndDistanceFromStartAndEnd(positionWS, GetOccluderPositionRWS(data), occluderFromSurfaceDirectionOS, occluderFromSurfaceDistance);

    float3 CapsuleSpaceX;
    float3 CapsuleSpaceY;
    float3 CapsuleSpaceZ = normalize(GetOccluderDirectionWS(data).xyz);
    GetOrthoBasis(CapsuleSpaceZ, CapsuleSpaceX, CapsuleSpaceY);
    float CapsuleZScale = GetOccluderRadius(data) / (.5f * GetOccluderScaling(data) + GetOccluderRadius(data));
    CapsuleSpaceZ *= CapsuleZScale;

    occluderFromSurfaceDirectionOS = positionWS - GetOccluderPositionRWS(data);
    occluderFromSurfaceDirectionOS = float3(dot(occluderFromSurfaceDirectionOS, CapsuleSpaceX), dot(occluderFromSurfaceDirectionOS, CapsuleSpaceY), dot(occluderFromSurfaceDirectionOS, CapsuleSpaceZ));

    occluderFromSurfaceDistance = length(occluderFromSurfaceDirectionOS);
    occluderFromSurfaceDirectionOS = normalize(occluderFromSurfaceDirectionOS);

    // Angle between occluder and cone axis
    float3 coneAxisOS = TransformDirection(coneAxis, data);
    coneAxisOS = normalize(coneAxis);

    coneAxisOS = float3(dot(coneAxisOS, CapsuleSpaceX), dot(coneAxisOS, CapsuleSpaceY), dot(coneAxisOS, CapsuleSpaceZ));


    float cosPhi = dot(coneAxisOS, occluderFromSurfaceDirectionOS);

    float tanTheta = radius / occluderFromSurfaceDistance;
    float theta = FastATanPos(tanTheta);

    float sinTheta = sin(theta);
    float occlusion = SAMPLE_TEXTURE3D_LOD(_CapsuleShadowLUT, s_linear_clamp_sampler, float3(0.5f * cosPhi + 0.5f, sinTheta, 0), 0).x;

    return ApplyInfluenceFalloff(occlusion, ComputeInfluenceFalloff(length(GetOccluderPositionRWS(data) - positionWS), GetOccluderInfluenceRadiusWS(data)));
}


float EvaluateCapsuleShadowLUT(EllipsoidOccluderData data, float3 positionWS, float3 N, float4 dirAndLength)
{
    // For now assuming just directional light.
    float3 coneAxis = _CapsuleShadowParameters.xyz;

    if (_CapsuleShadowIsPunctual)
    {
        float3 lightPos = _CapsuleShadowParameters.xyz;
        coneAxis = normalize(lightPos - positionWS);
    }

    float radius = GetOccluderRadius(data);
    float4 dirAndLen = GetDataForSphereIntersection(data, positionWS);
    
    float3 occluderFromSurfaceDirectionOS = dirAndLen.xyz;
    float occluderFromSurfaceDistance = dirAndLen.w;

    // Angle between occluder and cone axis
    float3 coneAxisOS = TransformDirection (coneAxis, data);
    float cosPhi = dot(coneAxisOS, occluderFromSurfaceDirectionOS);

    float tanTheta = radius / occluderFromSurfaceDistance;
    float theta = FastATanPos(tanTheta);

    float sinTheta = sin(theta);
    float occlusionVal = SAMPLE_TEXTURE3D_LOD(_CapsuleShadowLUT, s_linear_clamp_sampler, float3(0.5f * cosPhi+ 0.5f, sinTheta, 0), 0).x;

    occlusionVal = ApplyInfluenceFalloff(occlusionVal, ComputeInfluenceFalloff(occluderFromSurfaceDistance, GetOccluderInfluenceRadiusWS(data)));
    
    return occlusionVal;
}

// --------------------------------------------
// Accumulation functions
// --------------------------------------------
// Functions used to accumulate results coming from different capsules.
// Min should be a safe bet, but abstract away in case more complex accumulation is required.

float AccumulateCapsuleAmbientOcclusion(float prevAO, float capsuleAO)
{
    return prevAO * (1.0-capsuleAO);
}

float AccumulateCapsuleSpecularOcclusion(float prevSpecOcc, float capsuleSpecOcc)
{
    return prevSpecOcc * capsuleSpecOcc;
}

float AccumulateCapsuleShadow(float prevShadow, float capsuleShadow)
{
    return prevShadow  * capsuleShadow;
}

// --------------------------------------------
// Main evaluation function
// --------------------------------------------
// This is the main loop through the capsule data. To change the intersection behaviour just modify the functions above.
// Should be responsability of the caller to avoid calling this when evaluationFlags == CAPSULEOCCLUSIONTYPE_NONE

void EvaluateCapsuleOcclusion(uint evaluationFlags,
                              PositionInputs posInput,
                              float3 N,
                              float3 V,
                              float roughness,
                              inout float ambientOcclusion,
                              inout float specularOcclusion,
                              inout float shadow)
{
    uint sphereCount, sphereStart;

#ifndef LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
    GetCountAndStart(posInput, LIGHTCATEGORY_CAPSULE_OCCLUDER, sphereStart, sphereCount);
#else   // LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
    sphereCount = /* TO ADD FIXED COUNT */ ; 
    sphereStart = 0;
#endif

    bool fastPath = false;
#if SCALARIZE_LIGHT_LOOP
    uint sphereStartLane0;
    fastPath = IsFastPath(sphereStart, sphereStartLane0);

    if (fastPath)
    {
        sphereStart = sphereStartLane0;
    }
#endif

    // Scalarized loop. All spheres that are in a tile/cluster touched by any pixel in the wave are loaded (scalar load), only the one relevant to current thread/pixel are processed.
    // For clarity, the following code will follow the convention: variables starting with s_ are meant to be wave uniform (meant for scalar register),
    // v_ are variables that might have different value for each thread in the wave (meant for vector registers).
    // This will perform more loads than it is supposed to, however, the benefits should offset the downside, especially given that light data accessed should be largely coherent.
    // Note that the above is valid only if wave intriniscs are supported.
    uint v_sphereListOffset = 0;
    uint v_sphereIdx = sphereStart;

    while (v_sphereListOffset < sphereCount)
    {
        v_sphereIdx = FetchIndex(sphereStart, v_sphereListOffset);
        uint s_sphereIdx = ScalarizeElementIndex(v_sphereIdx, fastPath);
        if (s_sphereIdx == -1)
            break;

        EllipsoidOccluderData s_capsuleData = FetchEllipsoidOccluderData(s_sphereIdx);

        // If current scalar and vector sphere index match, we process the sphere. The v_sphereListOffset for current thread is increased.
        // Note that the following should really be ==, however, since helper lanes are not considered by WaveActiveMin, such helper lanes could
        // end up with a unique v_sphereIdx value that is smaller than s_sphereIdx hence being stuck in a loop. All the active lanes will not have this problem.
        if (s_sphereIdx >= v_sphereIdx)
        {
            v_sphereListOffset++;

            float4 dirAndLen = GetDataForSphereIntersection(s_capsuleData, posInput.positionWS);

            if (evaluationFlags & CAPSULEOCCLUSIONTYPE_AMBIENT_OCCLUSION)
            {
                float capsuleAO = EvaluateCapsuleAmbientOcclusion(s_capsuleData, posInput.positionWS, N, dirAndLen);
                ambientOcclusion = AccumulateCapsuleAmbientOcclusion(ambientOcclusion, capsuleAO);
            }

            if (evaluationFlags & CAPSULEOCCLUSIONTYPE_SPECULAR_OCCLUSION)
            {
                float capsuleSpecOcc = EvaluateCapsuleSpecularOcclusion(s_capsuleData, posInput.positionWS, N, V, roughness, dirAndLen);
                specularOcclusion = AccumulateCapsuleSpecularOcclusion(specularOcclusion, capsuleSpecOcc);
            }

            if (evaluationFlags & CAPSULEOCCLUSIONTYPE_DIRECTIONAL_SHADOWS)
            {
                float capsuleShadow = EvaluateCapsuleShadowAnalytical2(s_capsuleData, posInput.positionWS, N, dirAndLen);
                shadow = AccumulateCapsuleShadow(shadow, capsuleShadow);
            }
        }
    }

    specularOcclusion = PositivePow(specularOcclusion, _CapsuleSpecularOcclusionIntensity);
    ambientOcclusion = PositivePow(ambientOcclusion, _CapsuleAmbientOcclusionIntensity);
}


#endif

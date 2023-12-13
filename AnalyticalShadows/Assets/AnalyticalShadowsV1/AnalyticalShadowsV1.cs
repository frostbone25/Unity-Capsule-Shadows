using System;
using System.Collections;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using AnalyticalShadowsShared;

namespace AnalyticalShadowsV1
{
    [Serializable]
    [PostProcess(typeof(AnalyticalShadowsV1Renderer), PostProcessEvent.BeforeTransparent, "Custom/AnalyticalShadowsV1")]
    public sealed class AnalyticalShadowsV1 : PostProcessEffectSettings
    {
        [Header("Setup")]
        public ComputeShaderParameter computeShader = new ComputeShaderParameter() { value = null };

        [Header("Apperance")]
        public FloatParameter intensity = new FloatParameter() { value = 1.0f };
        [Range(0.0f, 1.0f)] public FloatParameter maxIntensityClamp = new FloatParameter() { value = 1.0f };
        [Range(1.0f, 0.0f)] public FloatParameter selfShadowIntensity = new FloatParameter() { value = 0.0f };
        [Range(1, 90)] public FloatParameter coneAngle = new FloatParameter() { value = 45.0f };

        [Header("Rendering")]
        [Range(1, 32)] public IntParameter downsample = new IntParameter() { value = 4 };
        public Vector3Parameter globalDirection = new Vector3Parameter() { value = new Vector3(0, 1, 0) };
        public AnalyticalShadowsDirectionTypeParameter directionType = new AnalyticalShadowsDirectionTypeParameter() { value = AnalyticalShadowsDirectionType.GlobalDirection };
        public BoolParameter traceBoxColliders = new BoolParameter() { value = true };
        public BoolParameter traceSphereColliders = new BoolParameter() { value = true };
        public BoolParameter traceCapsuleColliders = new BoolParameter() { value = true };

        [Header("Filtering")]
        public BoolParameter useBilaterialBlur = new BoolParameter() { value = true };
        public BoolParameter highQualityBilaterialBlur = new BoolParameter() { value = false };
        public FloatParameter bilaterialGeometryCoeff = new FloatParameter() { value = 0.8f };

        [Header("Debugging")]
        public BoolParameter rebuildShapes = new BoolParameter() { value = true };
        public BoolParameter updateShapes = new BoolParameter() { value = true };
    }
}
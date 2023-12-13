using AnalyticalShadows;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Profiling;

namespace AnalyticalShadowsV1
{
    public static class AnalyticalShadowsV1_IDs
    {
        internal static readonly int MainTex = Shader.PropertyToID("_MainTex");
        internal static readonly int ViewProjectionInverse = Shader.PropertyToID("_ViewProjInv");
        internal static readonly int ComputeShaderResult = Shader.PropertyToID("_ComputeShaderResult");
        internal static readonly int Intensity = Shader.PropertyToID("_Intensity");
        internal static readonly int RenderTarget = Shader.PropertyToID("_RenderTarget");
        internal static readonly int kGeometryCoeff = Shader.PropertyToID("kGeometryCoeff");
        internal static readonly int Cubes = Shader.PropertyToID("Cubes");
        internal static readonly int Spheres = Shader.PropertyToID("Spheres");
        internal static readonly int Capsules = Shader.PropertyToID("Capsules");
        internal static readonly int RenderResolution = Shader.PropertyToID("_RenderResolution");
        internal static readonly int WorldPosition = Shader.PropertyToID("WorldPosition");
        internal static readonly int DirectionalBuffer = Shader.PropertyToID("DirectionalBuffer");
        internal static readonly int MaskBuffer = Shader.PropertyToID("MaskBuffer");
        internal static readonly int Result = Shader.PropertyToID("Result");
        internal static readonly int OccluderRadiusMultiplier = Shader.PropertyToID("_OccluderRadiusMultiplier");
        internal static readonly int ConeAngle = Shader.PropertyToID("_ConeAngle");
        internal static readonly int Distance = Shader.PropertyToID("_Distance");
        internal static readonly int Direction = Shader.PropertyToID("_Direction");
    }
}
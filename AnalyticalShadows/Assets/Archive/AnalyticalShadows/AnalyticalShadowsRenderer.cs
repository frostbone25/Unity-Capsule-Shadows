using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UIElements;
using static UnityEditor.ShaderData;
using static UnityEngine.Rendering.PostProcessing.PostProcessResources;
using AnalyticalShadowsShared;

/*
TODO:
- Improve Bilaterial Blur? (It works, but its done at full res and im not fully sure if it was implemented optmially)
- Use proper command buffers for the Directional/Mask buffers rather than just using 2 cameras with replacement shaders, doesn't seem like the best solution.
- Needs a proper box tracing function
- Needs also another option to simplify all of the box/sphere/capsule tracings by instead opting for a single elipsoid tracing function. 
- Find a way to optimize the shape compute buffers by only rebuilding if new shapes are introduced/or if the camera moves. They have been seperated in anticipation for this.

IDEAS:
- Use interleaved + temporal rendering? (not sure because the effect does not require any jittering of the samples so this may not be necessary).
- Check up if using Shader Property IDs are faster than just using the classic string for setting properties/textures on shaders. 

SELF NOTES
- Done in TLOU 1, to approximate the shapes we can easily do that with a stretched sphere for cheap, I got close with size however I can't figure out proper rotation for the shapes
*/

namespace AnalyticalShadows
{
    public sealed class AnalyticalShadowsRenderer : PostProcessEffectRenderer<AnalyticalShadows>
    {
        private bool useLightmapDirection = false;
        private bool useProbeDirection = false;
        private bool traceBoxColliders = false;
        private bool traceSphereColliders = false;
        private bool traceCapsuleColliders = false;

        private ComputeBuffer buffer_spheres;
        private ComputeBuffer buffer_cubes;
        private ComputeBuffer buffer_capsules;

        private Shader postShader;
        private Shader directionalBufferShader;
        private Shader maskBufferShader;

        private RenderTexture computeWrite = null;
        private RenderTexture directionalBuffer = null;
        private RenderTexture maskBuffer = null;
        private Camera cameraDirectionalBuffer;
        private Camera cameraMaskBuffer;

        public List<SphereStruct> sphereStructs;
        public List<CubeStruct> cubeStructs;
        public List<CapsuleStruct> capsuleStructs;

        public List<SphereCollider> sphereColliders;
        public List<BoxCollider> boxColliders;
        public List<CapsuleCollider> capsuleColliders;

        public override DepthTextureMode GetCameraFlags() => DepthTextureMode.Depth | DepthTextureMode.DepthNormals;

        private static void SetComputeKeyword(ComputeShader computeShader, string keyword, bool value)
        {
            if (value)
                computeShader.EnableKeyword(keyword);
            else
                computeShader.DisableKeyword(keyword);
        }

        private static void SetKeyword(PropertySheet sheet, string keyword, bool value)
        {
            if (value)
                sheet.EnableKeyword(keyword);
            else
                sheet.DisableKeyword(keyword);
        }

        private void Setup(PostProcessRenderContext context)
        {
            if (postShader == null)
                postShader = Shader.Find("Hidden/AnalyticalShadowsBuffer");

            if (directionalBufferShader == null)
                directionalBufferShader = Shader.Find("Hidden/DirectionalBuffer");

            if (maskBufferShader == null)
                maskBufferShader = Shader.Find("Hidden/MaskBuffer");
        }

        private void SetupCameraBuffers(PostProcessRenderContext context, int resolutionX, int resolutionY, int depthBits)
        {
            ///*
            if (cameraDirectionalBuffer == null)
            {
                GameObject cameraDirectionalBufferGameObject = new GameObject("AnalyticalShadows_DirectionalBuffer");
                cameraDirectionalBuffer = cameraDirectionalBufferGameObject.AddComponent<Camera>();
                cameraDirectionalBuffer.clearFlags = CameraClearFlags.SolidColor;
                cameraDirectionalBuffer.backgroundColor = UnityEngine.Color.black;
                cameraDirectionalBuffer.SetReplacementShader(directionalBufferShader, "");

                cameraDirectionalBufferGameObject.transform.SetParent(context.camera.transform);
                cameraDirectionalBufferGameObject.transform.localPosition = Vector3.zero;
                cameraDirectionalBufferGameObject.transform.localRotation = new Quaternion(0, 0, 0, 0);
            }

            if (cameraMaskBuffer == null)
            {
                GameObject cameraMaskBufferGameObject = new GameObject("AnalyticalShadows_MaskBuffer");
                cameraMaskBuffer = cameraMaskBufferGameObject.AddComponent<Camera>();
                cameraMaskBuffer.clearFlags = CameraClearFlags.SolidColor;
                cameraMaskBuffer.backgroundColor = UnityEngine.Color.black;
                cameraMaskBuffer.SetReplacementShader(maskBufferShader, "");

                cameraMaskBufferGameObject.transform.SetParent(context.camera.transform);
                cameraMaskBufferGameObject.transform.localPosition = Vector3.zero;
                cameraMaskBufferGameObject.transform.localRotation = new Quaternion(0, 0, 0, 0);
            }

            if (directionalBuffer == null)
            {
                directionalBuffer = new RenderTexture(resolutionX, resolutionY, depthBits, context.sourceFormat);
                directionalBuffer.filterMode = FilterMode.Bilinear;
                directionalBuffer.enableRandomWrite = true;
                directionalBuffer.Create();
            }

            if (maskBuffer == null)
            {
                maskBuffer = new RenderTexture(resolutionX, resolutionY, depthBits, RenderTextureFormat.R8);
                maskBuffer.filterMode = FilterMode.Bilinear;
                maskBuffer.enableRandomWrite = true;
                maskBuffer.Create();
            }

            cameraDirectionalBuffer.fieldOfView = context.camera.fieldOfView;
            cameraDirectionalBuffer.nearClipPlane = context.camera.nearClipPlane;
            cameraDirectionalBuffer.farClipPlane = context.camera.farClipPlane;

            cameraMaskBuffer.fieldOfView = context.camera.fieldOfView;
            cameraMaskBuffer.nearClipPlane = context.camera.nearClipPlane;
            cameraMaskBuffer.farClipPlane = context.camera.farClipPlane;

            cameraDirectionalBuffer.targetTexture = directionalBuffer;
            cameraMaskBuffer.targetTexture = maskBuffer;

            cameraDirectionalBuffer.Render();
            cameraMaskBuffer.Render();
            //*/

            /*
            directionalBuffer = RenderTexture.GetTemporary(resolutionX, resolutionY, depthBits, context.sourceFormat);
            //directionalBuffer.enableRandomWrite = true;
            directionalBuffer.filterMode = FilterMode.Bilinear;
            context.camera.SetReplacementShader(directionalBufferShader, "");
            context.command.BlitFullscreenTriangle(context.source, directionalBuffer, context.propertySheets.Get(postShader), 2);
            //context.command.Blit(context.source, directionalBuffer);

            maskBuffer = RenderTexture.GetTemporary(resolutionX, resolutionY, depthBits, context.sourceFormat);
            //maskBuffer.enableRandomWrite = true;
            maskBuffer.filterMode = FilterMode.Bilinear;
            context.camera.SetReplacementShader(maskBufferShader, "");
            context.command.BlitFullscreenTriangle(context.source, maskBuffer, context.propertySheets.Get(postShader), 2);
            //context.command.Blit(context.source, maskBuffer);

            context.camera.ResetReplacementShader();
            */
        }

        private void BuildShapeBuffers(Vector3 cameraPosition, float distance)
        {
            /*
            Collider[] colliders = Physics.OverlapSphere(cameraPosition, distance);

            if (sphereColliders == null) 
                sphereColliders = new List<SphereCollider>();
            else
                sphereColliders.Clear();

            if (boxColliders == null) 
                boxColliders = new List<BoxCollider>();
            else
                boxColliders.Clear();

            if (capsuleColliders == null) 
                capsuleColliders = new List<CapsuleCollider>();
            else
                capsuleColliders.Clear();

            for (int i = 0; i < colliders.Length; i++)
            {
                CapsuleCollider capsuleCollider = colliders[i].GetComponent<CapsuleCollider>();
                BoxCollider boxCollider = colliders[i].GetComponent<BoxCollider>();
                SphereCollider sphereCollider = colliders[i].GetComponent<SphereCollider>();

                if (capsuleCollider != null && capsuleCollider.enabled && !capsuleCollider.isTrigger && traceCapsuleColliders)
                    capsuleColliders.Add(capsuleCollider);

                if (boxCollider != null && boxCollider.enabled && !boxCollider.isTrigger && traceBoxColliders)
                    boxColliders.Add(boxCollider);

                if (sphereCollider != null && sphereCollider.enabled && !sphereCollider.isTrigger && traceSphereColliders)
                    sphereColliders.Add(sphereCollider);
            }

            sphereStructs = new SphereStruct[sphereColliders.Count];
            cubeStructs = new CubeStruct[boxColliders.Count];
            capsuleStructs = new CapsuleStruct[capsuleColliders.Count];

            for (int i = 0; i < sphereStructs.Length; i++) sphereStructs[i] = new SphereStruct();
            for (int i = 0; i < cubeStructs.Length; i++) cubeStructs[i] = new CubeStruct();
            for (int i = 0; i < capsuleStructs.Length; i++) capsuleStructs[i] = new CapsuleStruct();

            if (buffer_capsules != null) buffer_capsules.Release();
            if (buffer_spheres != null) buffer_spheres.Release();
            if (buffer_cubes != null) buffer_cubes.Release();

            if (sphereStructs.Length > 0) buffer_spheres = new ComputeBuffer(sphereStructs.Length, SphereStruct.GetByteSize() * sphereStructs.Length);
            if (cubeStructs.Length > 0) buffer_cubes = new ComputeBuffer(cubeStructs.Length, CubeStruct.GetByteSize() * cubeStructs.Length);
            if (capsuleStructs.Length > 0) buffer_capsules = new ComputeBuffer(capsuleStructs.Length, CapsuleStruct.GetByteSize() * capsuleStructs.Length);
            */

            AnalyticalShadowCaster[] analyticalShadowCasters = GameObject.FindObjectsOfType<AnalyticalShadowCaster>();

            cubeStructs = new List<CubeStruct>();
            sphereStructs = new List<SphereStruct>();
            capsuleStructs = new List<CapsuleStruct>();

            foreach(AnalyticalShadowCaster analyticalShadowCaster in analyticalShadowCasters)
            {
                if (analyticalShadowCaster.boxCollider != null && traceBoxColliders)
                    cubeStructs.Add(analyticalShadowCaster.cubeStruct);

                if (analyticalShadowCaster.sphereCollider != null && traceSphereColliders)
                    sphereStructs.Add(analyticalShadowCaster.sphereStruct);

                if (analyticalShadowCaster.capsuleCollider != null && traceCapsuleColliders)
                    capsuleStructs.Add(analyticalShadowCaster.capsuleStruct);
            }

            if (buffer_cubes != null) buffer_cubes.Release();
            if (buffer_spheres != null) buffer_spheres.Release();
            if (buffer_capsules != null) buffer_capsules.Release();

            if (cubeStructs.Count > 0) buffer_cubes = new ComputeBuffer(cubeStructs.Count, CubeStruct.GetByteSize() * cubeStructs.Count);
            if (sphereStructs.Count > 0) buffer_spheres = new ComputeBuffer(sphereStructs.Count, SphereStruct.GetByteSize() * sphereStructs.Count);
            if (capsuleStructs.Count > 0) buffer_capsules = new ComputeBuffer(capsuleStructs.Count, CapsuleStruct.GetByteSize() * capsuleStructs.Count);
        }

        public override void Release()
        {
            base.Release();

            if (sphereColliders != null) sphereColliders.Clear();
            if (boxColliders != null) boxColliders.Clear();
            if (capsuleColliders != null) capsuleColliders.Clear();

            if (buffer_capsules != null) buffer_capsules.Release();
            if (buffer_spheres != null) buffer_spheres.Release();
            if (buffer_cubes != null) buffer_cubes.Release();

            MonoBehaviour.DestroyImmediate(cameraDirectionalBuffer.gameObject);
            MonoBehaviour.DestroyImmediate(cameraMaskBuffer.gameObject);

            if (directionalBuffer != null) directionalBuffer.Release();
            if (maskBuffer != null) maskBuffer.Release();
            if (computeWrite != null) computeWrite.Release();
        }

        private void UpdateShapeBuffers()
        {
            if (sphereStructs.Count > 0) buffer_spheres.SetData(sphereStructs);
            if (cubeStructs.Count > 0) buffer_cubes.SetData(cubeStructs);
            if (capsuleStructs.Count > 0) buffer_capsules.SetData(capsuleStructs);
        }

        public override void Render(PostProcessRenderContext context)
        {
            Setup(context);

            if (settings.rebuildShapes.value) 
                BuildShapeBuffers(context.camera.transform.position, settings.distance.value);

            if (settings.updateShapes.value) 
                UpdateShapeBuffers();

            if (postShader == null)
            {
                postShader = Shader.Find("Hidden/AnalyticalShadowsBuffer");
                return;
            }

            PropertySheet sheet = context.propertySheets.Get(postShader);
            ComputeShader computeShader = settings.computeShader.value;
            Texture cameraDepthTexture = Shader.GetGlobalTexture("_CameraDepthTexture");
            Texture cameraDepthNormalsTexture = Shader.GetGlobalTexture("_CameraDepthNormalsTexture");

            if (computeShader == null || cameraDepthTexture == null || cameraDepthNormalsTexture == null)
                return;

            useLightmapDirection = settings.directionType.value == AnalyticalShadowsDirectionType.StaticLightmapDirection;
            useProbeDirection = settings.directionType.value == AnalyticalShadowsDirectionType.ProbeDirection;
            traceBoxColliders = settings.traceBoxColliders.value;
            traceSphereColliders = settings.traceSphereColliders.value;
            traceCapsuleColliders = settings.traceCapsuleColliders.value;

            context.command.BeginSample("Analytical Shadows");

            int depthBits = 16; //16, 24, 32
            int resolutionX = context.width / settings.downsample.value;
            int resolutionY = context.height / settings.downsample.value;

            SetupCameraBuffers(context, resolutionX, resolutionY, depthBits);

            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            //|||||||||||||||||||||||||| COMPUTE SHADER ||||||||||||||||||||||||||
            if(computeWrite != null)
            {
                if (computeWrite.IsCreated())
                    computeWrite.Release();
            }

            computeWrite = new RenderTexture(resolutionX, resolutionY, depthBits, context.sourceFormat, 0);
            computeWrite.filterMode = FilterMode.Bilinear;
            computeWrite.enableRandomWrite = true;
            computeWrite.Create();

            int compute_main = computeShader.FindKernel("CSMain");

            computeShader.SetTexture(compute_main, "_CameraDepthTexture", cameraDepthTexture);
            computeShader.SetTexture(compute_main, "_CameraDepthNormalsTexture", cameraDepthNormalsTexture);

            Matrix4x4 viewProjMat = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false) * context.camera.worldToCameraMatrix;
            computeShader.SetMatrix("_ViewProjInv", viewProjMat.inverse);

            context.command.SetComputeVectorParam(computeShader, "_RenderResolution", new Vector4(resolutionX, resolutionY, 0, 0));
            context.command.SetComputeFloatParam(computeShader, "_Distance", settings.distance.value);
            context.command.SetComputeFloatParam(computeShader, "_ConeAngle", settings.coneAngle.value);

            if (useProbeDirection)
                SetComputeKeyword(computeShader, "USE_PROBE_DIRECTION", true);
            else
                SetComputeKeyword(computeShader, "USE_PROBE_DIRECTION", false);

            if (useLightmapDirection)
            {
                SetComputeKeyword(computeShader, "USE_LIGHTMAP_DIRECTION", true);
                context.command.SetComputeTextureParam(computeShader, compute_main, "DirectionalBuffer", directionalBuffer);
            }
            else
            {
                SetComputeKeyword(computeShader, "USE_LIGHTMAP_DIRECTION", false);
                context.command.SetComputeVectorParam(computeShader, "_GlobalDirection", settings.globalDirection.value);
            }

            if (traceCapsuleColliders && buffer_capsules != null && buffer_capsules.IsValid())
            {
                SetComputeKeyword(computeShader, "TRACE_CAPSULE_COLLIDERS", true);
                context.command.SetComputeBufferParam(computeShader, compute_main, "Capsules", buffer_capsules);
            }
            else
                SetComputeKeyword(computeShader, "TRACE_CAPSULE_COLLIDERS", false);

            if (traceSphereColliders && buffer_spheres != null && buffer_spheres.IsValid())
            {
                SetComputeKeyword(computeShader, "TRACE_SPHERE_COLLIDERS", true);
                context.command.SetComputeBufferParam(computeShader, compute_main, "Spheres", buffer_spheres);
            }
            else
                SetComputeKeyword(computeShader, "TRACE_SPHERE_COLLIDERS", false);

            if (traceBoxColliders && buffer_cubes != null && buffer_cubes.IsValid())
            {
                SetComputeKeyword(computeShader, "TRACE_BOX_COLLIDERS", true);
                context.command.SetComputeBufferParam(computeShader, compute_main, "Cubes", buffer_cubes);
            }
            else
                SetComputeKeyword(computeShader, "TRACE_BOX_COLLIDERS", false);

            context.command.SetComputeTextureParam(computeShader, compute_main, "MaskBuffer", maskBuffer);
            context.command.SetComputeTextureParam(computeShader, compute_main, "Result", computeWrite);
            context.command.DispatchCompute(computeShader, compute_main, Mathf.CeilToInt(resolutionX / 8f), Mathf.CeilToInt(resolutionY / 8f), 1);

            if(settings.useBilaterialBlur.value)
            {
                //not a fan of doing these at full res but it looks the best
                var downsample = RenderTexture.GetTemporary(context.width, context.height, depthBits, context.sourceFormat);
                var bilaterialH = RenderTexture.GetTemporary(context.width, context.height, depthBits, context.sourceFormat);
                var bilaterialV = RenderTexture.GetTemporary(context.width, context.height, depthBits, context.sourceFormat);
                downsample.filterMode = FilterMode.Bilinear;
                bilaterialH.filterMode = FilterMode.Bilinear;
                bilaterialV.filterMode = FilterMode.Bilinear;

                sheet.properties.SetTexture("_ComputeShaderResult", computeWrite);
                context.command.BlitFullscreenTriangle(context.source, downsample, sheet, 3);

                sheet.properties.SetTexture("_RenderTarget", downsample);
                sheet.properties.SetInt("_DownsampleFactor", settings.downsample.value);
                sheet.properties.SetFloat("kGeometryCoeff", settings.bilaterialGeometryCoeff.value);
                SetKeyword(sheet, "BLUR_HIGH_QUALITY", settings.highQualityBilaterialBlur.value);
                context.command.BlitFullscreenTriangle(context.source, bilaterialH, sheet, 4);

                sheet.properties.SetTexture("_RenderTarget", bilaterialH);
                sheet.properties.SetInt("_DownsampleFactor", settings.downsample.value);
                sheet.properties.SetFloat("kGeometryCoeff", settings.bilaterialGeometryCoeff.value);
                SetKeyword(sheet, "BLUR_HIGH_QUALITY", settings.highQualityBilaterialBlur.value);
                context.command.BlitFullscreenTriangle(context.source, bilaterialV, sheet, 5);

                sheet.properties.SetFloat("_Intensity", settings.intensity.value);
                sheet.properties.SetFloat("_MaxIntensityClamp", settings.maxIntensityClamp.value);
                sheet.properties.SetFloat("_SelfShadowIntensity", settings.selfShadowIntensity.value);
                sheet.properties.SetTexture("_MaskBuffer", maskBuffer);
                sheet.properties.SetTexture("_ComputeShaderResult", bilaterialV);
                context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 2);

                RenderTexture.ReleaseTemporary(downsample);
                RenderTexture.ReleaseTemporary(bilaterialH);
                RenderTexture.ReleaseTemporary(bilaterialV);
            }
            else
            {
                sheet.properties.SetFloat("_Intensity", settings.intensity.value);
                sheet.properties.SetFloat("_MaxIntensityClamp", settings.maxIntensityClamp.value);
                sheet.properties.SetFloat("_SelfShadowIntensity", settings.selfShadowIntensity.value);
                sheet.properties.SetTexture("_MaskBuffer", maskBuffer);
                sheet.properties.SetTexture("_ComputeShaderResult", computeWrite);
                context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 2);
            }

            context.command.EndSample("Analytical Shadows");
        }
    }
}

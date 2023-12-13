using AnalyticalShadows;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace AnalyticalShadowsShared
{
    [ExecuteInEditMode]
    public class AnalyticalShadowCaster : MonoBehaviour
    {
        public Renderer meshRenderer;

        [HideInInspector] public BoxCollider boxCollider;
        [HideInInspector] public SphereCollider sphereCollider;
        [HideInInspector] public CapsuleCollider capsuleCollider;

        [HideInInspector] public CubeStruct cubeStruct;
        [HideInInspector] public SphereStruct sphereStruct;
        [HideInInspector] public CapsuleStruct capsuleStruct;

        private void Initalize()
        {
            if (meshRenderer == null) meshRenderer = GetComponent<Renderer>();

            boxCollider = GetComponent<BoxCollider>();
            sphereCollider = GetComponent<SphereCollider>();
            capsuleCollider = GetComponent<CapsuleCollider>();

            if (boxCollider != null) cubeStruct = new CubeStruct();
            if (sphereCollider != null) sphereStruct = new SphereStruct();
            if (capsuleCollider != null) capsuleStruct = new CapsuleStruct();
        }

        private void UpdateData()
        {
            Vector3 meshPosition;
            SphericalHarmonicsL2 probe;

            if (meshRenderer == null)
            {
                meshPosition = transform.position;
                LightProbes.GetInterpolatedProbe(meshPosition, null, out probe);
            }
            else
            {
                if (meshRenderer.probeAnchor)
                    meshPosition = meshRenderer.probeAnchor.position;
                else
                    meshPosition = meshRenderer.bounds.center;

                LightProbes.GetInterpolatedProbe(meshPosition, meshRenderer, out probe);
            }

            if (capsuleCollider != null)
            {
                capsuleStruct.SetData(capsuleCollider);
                capsuleStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirectionFast(probe);
            }

            if (sphereCollider != null)
            {
                sphereStruct.SetData(sphereCollider);
                sphereStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirectionFast(probe);
            }

            if (boxCollider != null)
            {
                cubeStruct.SetData(boxCollider);
                cubeStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirectionFast(probe);
            }
        }

        private static Vector3 GetSphericalHarmonicsDirectionFast(SphericalHarmonicsL2 sphericalHarmonicsL2)
        {
            //combine them all to get the dominant direction
            Vector3 combined = Vector3.zero;

            //add constant + linear
            combined += new Vector3(sphericalHarmonicsL2[0, 3], sphericalHarmonicsL2[0, 1], sphericalHarmonicsL2[0, 2]); //unity_SHAr
            combined += new Vector3(sphericalHarmonicsL2[1, 3], sphericalHarmonicsL2[1, 1], sphericalHarmonicsL2[1, 2]); //unity_SHAg
            combined += new Vector3(sphericalHarmonicsL2[2, 3], sphericalHarmonicsL2[2, 1], sphericalHarmonicsL2[2, 2]); //unity_SHAb

            return combined.normalized;
        }

        private static Vector3 GetSphericalHarmonicsDirection(SphericalHarmonicsL2 sphericalHarmonicsL2)
        {
            //combine them all to get the dominant direction
            Vector3 combined = Vector3.zero;

            //add constant + linear
            combined += new Vector3(sphericalHarmonicsL2[0, 3], sphericalHarmonicsL2[0, 1], sphericalHarmonicsL2[0, 2]); //unity_SHAr
            combined += new Vector3(sphericalHarmonicsL2[1, 3], sphericalHarmonicsL2[1, 1], sphericalHarmonicsL2[1, 2]); //unity_SHAg
            combined += new Vector3(sphericalHarmonicsL2[2, 3], sphericalHarmonicsL2[2, 1], sphericalHarmonicsL2[2, 2]); //unity_SHAb

            //add quadratic polynomials
            combined += new Vector3(sphericalHarmonicsL2[0, 4], sphericalHarmonicsL2[0, 6], sphericalHarmonicsL2[0, 5] * 3); //unity_SHBr
            combined += new Vector3(sphericalHarmonicsL2[1, 4], sphericalHarmonicsL2[1, 6], sphericalHarmonicsL2[1, 5] * 3); //unity_SHBg
            combined += new Vector3(sphericalHarmonicsL2[2, 4], sphericalHarmonicsL2[2, 6], sphericalHarmonicsL2[2, 5] * 3); //unity_SHBb

            //add final quadratic polynomial
            combined += new Vector3(sphericalHarmonicsL2[0, 8], sphericalHarmonicsL2[2, 8], sphericalHarmonicsL2[1, 8]); //unity_SHC

            return combined.normalized;
        }

        private void Awake()
        {
            Initalize();
            UpdateData();
        }

        private void Update()
        {
            UpdateData();
        }

        private void OnEnable()
        {
            Initalize();
            UpdateData();
        }
    }

}
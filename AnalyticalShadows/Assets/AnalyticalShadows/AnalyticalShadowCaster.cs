using AnalyticalShadows;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions.Must;
using UnityEngine.Rendering;

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
            capsuleStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirection(probe);
        }

        if (sphereCollider != null)
        {
            sphereStruct.SetData(sphereCollider);
            sphereStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirection(probe);
        }

        if (boxCollider != null)
        {
            cubeStruct.SetData(boxCollider);
            cubeStruct.sphericalHarmonicDirection = GetSphericalHarmonicsDirection(probe);
        }
    }

    private static Vector3 GetSphericalHarmonicsDirection(SphericalHarmonicsL2 sphericalHarmonicsL2)
    {
        //constant + linear
        Vector4 unity_SHAr = new Vector4(sphericalHarmonicsL2[0, 3], sphericalHarmonicsL2[0, 1], sphericalHarmonicsL2[0, 2], sphericalHarmonicsL2[0, 0] - sphericalHarmonicsL2[0, 6]);
        Vector4 unity_SHAg = new Vector4(sphericalHarmonicsL2[1, 3], sphericalHarmonicsL2[1, 1], sphericalHarmonicsL2[1, 2], sphericalHarmonicsL2[1, 0] - sphericalHarmonicsL2[1, 6]);
        Vector4 unity_SHAb = new Vector4(sphericalHarmonicsL2[2, 3], sphericalHarmonicsL2[2, 1], sphericalHarmonicsL2[2, 2], sphericalHarmonicsL2[2, 0] - sphericalHarmonicsL2[2, 6]);

        //quadratic polynomials
        Vector4 unity_SHBr = new Vector4(sphericalHarmonicsL2[0, 4], sphericalHarmonicsL2[0, 6], sphericalHarmonicsL2[0, 5] * 3, sphericalHarmonicsL2[0, 7]);
        Vector4 unity_SHBg = new Vector4(sphericalHarmonicsL2[1, 4], sphericalHarmonicsL2[1, 6], sphericalHarmonicsL2[1, 5] * 3, sphericalHarmonicsL2[1, 7]);
        Vector4 unity_SHBb = new Vector4(sphericalHarmonicsL2[2, 4], sphericalHarmonicsL2[2, 6], sphericalHarmonicsL2[2, 5] * 3, sphericalHarmonicsL2[2, 7]);

        //final quadratic polynomial
        Vector4 unity_SHC = new Vector4(sphericalHarmonicsL2[0, 8], sphericalHarmonicsL2[2, 8], sphericalHarmonicsL2[1, 8], 1);

        //combine them all to get the dominant direction
        Vector3 combined = Vector3.zero;

        //add constant + linear
        combined += new Vector3(unity_SHAr.x, unity_SHAr.y, unity_SHAr.z);
        combined += new Vector3(unity_SHAg.x, unity_SHAg.y, unity_SHAg.z);
        combined += new Vector3(unity_SHAb.x, unity_SHAb.y, unity_SHAb.z);

        //add quadratic polynomials
        combined += new Vector3(unity_SHBr.x, unity_SHBr.y, unity_SHBr.z);
        combined += new Vector3(unity_SHBg.x, unity_SHBg.y, unity_SHBg.z);
        combined += new Vector3(unity_SHBb.x, unity_SHBb.y, unity_SHBb.z);

        //add final quadratic polynomial
        combined += new Vector3(unity_SHC.x, unity_SHC.y, unity_SHC.z);

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

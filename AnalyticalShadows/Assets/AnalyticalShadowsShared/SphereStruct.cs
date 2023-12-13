using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using UnityEngine;

namespace AnalyticalShadowsShared
{
    [Serializable]
    public struct SphereStruct
    {
        public Vector3 position;
        public float radius;
        public Vector3 sphericalHarmonicDirection;

        public static int GetByteSize()
        {
            int result = 0;

            result += 4 * 3; //[12 bytes] position
            result += 4; //[4 bytes] radius
            result += 4 * 3; //[12 bytes] sphericalHarmonicDirection

            return result;
        }

        public void SetData(SphereCollider sphereCollider)
        {
            position = sphereCollider.transform.TransformPoint(sphereCollider.center);
            radius = sphereCollider.radius * sphereCollider.transform.lossyScale.magnitude;
        }
    }
}
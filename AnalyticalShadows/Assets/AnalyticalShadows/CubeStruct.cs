using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace AnalyticalShadows
{
    [Serializable]
    public struct CubeStruct
    {
        public Vector3 position;
        public Vector3 size;
        public Vector4 rotation;
        public Vector3 sphericalHarmonicDirection;

        public static int GetByteSize()
        {
            int result = 0;

            result += 4 * 3; //[12 bytes] position
            result += 4 * 3; //[12 bytes] size
            result += 4 * 4; //[16 bytes] rotation
            result += 4 * 3; //[12 bytes] sphericalHarmonicDirection

            return result;
        }

        public void SetData(BoxCollider boxCollider)
        {
            position = boxCollider.transform.TransformPoint(boxCollider.center);
            size = Vector3.Scale(boxCollider.size, boxCollider.transform.lossyScale);
            rotation = boxCollider.transform.up;
            //rotation = new Vector4(boxCollider.transform.rotation.x, boxCollider.transform.rotation.y, boxCollider.transform.rotation.z, boxCollider.transform.rotation.w);
        }
    }
}
using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using UnityEngine;

namespace AnalyticalShadows
{
    [Serializable]
    public struct CapsuleStruct
    {
        public Vector3 position;
        public Vector3 direction;
        public float height;
        public float radius;
        public Vector4 rotation;
        public Vector3 sphericalHarmonicDirection;

        public static int GetByteSize()
        {
            int result = 0;

            result += 4 * 3; //[12 bytes] position
            result += 4 * 3; //[12 bytes] direction
            result += 4; //[4 bytes] height
            result += 4; //[4 bytes] radius
            result += 4 * 4; //[16 bytes] rotation
            result += 4 * 3; //[12 bytes] sphericalHarmonicDirection

            return result;
        }

        public void SetData(CapsuleCollider capsuleCollider)
        {
            Vector3 capsuleDirection = Vector3.zero;
            float capsuleHeight = capsuleCollider.height;
            float capsuleRadius = capsuleCollider.radius;
            float capsuleDirectionFactor = 1.0f;

            if (capsuleCollider.direction == 0)
            {
                capsuleDirection = new Vector3(capsuleDirectionFactor, 0, 0);
                capsuleHeight *= capsuleCollider.transform.lossyScale.x;
                capsuleRadius *= Mathf.Max(capsuleCollider.transform.lossyScale.y, capsuleCollider.transform.lossyScale.z);
            }
            else if (capsuleCollider.direction == 1)
            {
                capsuleDirection = new Vector3(0, capsuleDirectionFactor, 0);
                capsuleHeight *= capsuleCollider.transform.lossyScale.y;
                capsuleRadius *= Mathf.Max(capsuleCollider.transform.lossyScale.z, capsuleCollider.transform.lossyScale.x);
            }
            else if (capsuleCollider.direction == 2)
            {
                capsuleDirection = new Vector3(0, 0, capsuleDirectionFactor);
                capsuleHeight *= capsuleCollider.transform.lossyScale.z;
                capsuleRadius *= Mathf.Max(capsuleCollider.transform.lossyScale.y, capsuleCollider.transform.lossyScale.x);
            }

            position = capsuleCollider.transform.TransformPoint(capsuleCollider.center);
            direction = capsuleCollider.transform.TransformDirection(capsuleDirection);
            height = capsuleHeight * 0.5f;
            radius = capsuleRadius;
            rotation = capsuleCollider.transform.forward;
        }
    }
}
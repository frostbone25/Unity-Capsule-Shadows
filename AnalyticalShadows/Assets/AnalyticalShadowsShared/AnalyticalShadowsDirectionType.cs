using System;

namespace AnalyticalShadowsShared
{
    [Serializable]
    public enum AnalyticalShadowsDirectionType
    {
        GlobalDirection,
        ProbeDirection, //Light Probe Dominant Direction
        StaticLightmapDirection, //Regular Lightmaps
        DynamicLightmapDirection //Enlighten Lightmaps
    }
}
//-------------------------------------------------------------------------
//came from - https://github.com/Unity-Technologies/Graphics/blob/draft/rp/capsule-shadows/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl

// Input [0, 1] and output [0, PI/2]
// 9 VALU
float FastACosPos(float inX)
{
    float x = abs(inX);
    float res = (0.0468878 * x + -0.203471) * x + 1.570796; // p(x)
    res *= sqrt(1.0 - x);

    return res;
}

// Ref: https://seblagarde.wordpress.com/2014/12/01/inverse-trigonometric-functions-gpu-optimization-for-amd-gcn-architecture/
// Input [-1, 1] and output [0, PI]
// 12 VALU
float FastACos(float inX)
{
    float res = FastACosPos(inX);

    return (inX >= 0) ? res : PI - res; // Undo range reduction
}

// max absolute error 1.3x10^-3
// Eberly's odd polynomial degree 5 - respect bounds
// 4 VGPR, 14 FR (10 FR, 1 QR), 2 scalar
// input [0, infinity] and output [0, PI/2]
float FastATanPos(float x)
{
    float t0 = (x < 1.0) ? x : 1.0 / x;
    float t1 = t0 * t0;
    float poly = 0.0872929;

    poly = -0.301895 + poly * t1;
    poly = 1.0 + poly * t1;
    poly = poly * t0;

    //return (x < 1.0) ? poly : HALF_PI - poly;
    return (x < 1.0) ? poly : PI - poly;
}

//-------------------------------------------------------------------------

float acosFast(float x)
{
    // Lagarde 2014, "Inverse trigonometric functions GPU optimization for AMD GCN architecture"
    // This is the approximation of degree 1, with a max absolute error of 9.0x10^-3
    float y = abs(x);
    float p = -0.1565827 * y + 1.570796;
    p *= sqrt(1.0 - y);
    return x >= 0.0 ? p : PI - p;
}

float acosFastPositive(float x)
{
    // Lagarde 2014, "Inverse trigonometric functions GPU optimization for AMD GCN architecture"
    float p = -0.1565827 * x + 1.570796;
    return p * sqrt(1.0 - x);
}
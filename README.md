# Unity Capsule Shadows

A work in progress solution for capsule shadows in Unity.

***More details will be revealed but it's very much a work in progress...***

# Results
![char1](GithubContent/char1.png)

![env1](GithubContent/env1.png)

# Features

Capsule shadows for dynamic objects.

- Compute Shader based.
- Adjustable softness via cone angle.
- Self shadowing support.
- Sample light directionality from multiple sources (Lightmap Directionality, Spherical Harmonics via Probes, or a Global Direction).
- Bilinear filter for upsampling when the effect is performed at a lower resolution.

**NOTE: Constructed on the Built-In Rendering Pipeline.**

# More Context

This effect is meant to be used to help ground dynamic objects with static objects, which is typical after when lightmapping scenes that are using purely baked lighting. This effect is akin to analytical shadows in that it uses primitives to cast shadows i.e. Box, Spheres, and Capsules. It uses Unity PhysX colliders to it's advantage to get those primitive shapes that normally would be defined for dynamic objects/characters. So if you already have a bunch of colliders for your characters/objects defined then this effect should be very trivial to implement.

It also drives me up the wall that there is at the time of writing no public implementation of this effect implemented in Unity (or other engines). For how useful the effect is for grounding dynamic objects in your scene its very transformative, so your welcome. If you'd like to also contribute to this effect and help make it better than please feel free!

# TODO

- VR Support (MAIN GOAL)
- Replace the dual cameras I use that create my Directionality/Mask buffers with a proper implementation via command buffers or some other way, I'm not happy with the current way I have it.
- Proper Box tracing function
- Find a way to optimize the shape compute buffers by only updating/rebuilding when necessary (i.e. only updating when shapes have been moved)
- Move the entire effect into a single compute shader for ease.
- Using a tretched elipsoid function for approximating all of the current shapes like Boxes, Capsules, and Spheres for improved performance (as proposed in the first last of us paper)
- Implement a LUT generation for the cone angle (as proposed in the first last of us paper)

### Sources/Credits

- [https://www.shadertoy.com/view/3stcD4](https://www.shadertoy.com/view/3stcD4)
- [Lighting Technology of The Last of Us Part II](https://history.siggraph.org/learning/lighting-technology-of-the-last-of-us-part-ii-by-doghramachi/)
- [Lighting technology of the last of us](http://miciwan.com/SIGGRAPH2013/Lighting%20Technology%20of%20The%20Last%20Of%20Us.pdf)

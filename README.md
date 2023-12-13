# Unity Capsule Shadows

A work in progress solution for capsule shadows in Unity.

# Results
![char1](GithubContent/char1.png)

![env1](GithubContent/env1.png)

# Features

Capsule shadows for dynamic objects.

- Adjustable softness via cone angle.
- Self-shadowing support.
- Supports capsules, spheres, boxes (wip).
- Sample light directionality from multiple sources (Lightmap Directionality, Spherical Harmonics via Probes, or a Global Direction).
- Bilateral filter for upsampling when the effect is performed at a lower resolution.
- Compute Shader based.
- Scene-based variant that works without any post-processing *(requires camera depth texture)* and is per-object.

**NOTE: Constructed on the Built-In Rendering Pipeline.**

# Info

## Why use it

This effect is meant to be used to help ground dynamic objects with static objects, which is typical after when lightmapping scenes that are using purely baked lighting. This effect is akin to analytical shadows in that it uses primitives to cast shadows i.e. Box, Spheres, and Capsules. It uses Unity PhysX colliders to it's advantage to get those primitive shapes that normally would be defined for dynamic objects/characters. So if you already have a bunch of colliders for your characters/objects defined then this effect should be very trivial to implement.

It also drives me up the wall that there is at the time of writing no public implementation of this effect implemented in Unity (or other engines). For how useful the effect is for grounding dynamic objects in your scene its very transformative, so your welcome. If you'd like to also contribute to this effect and help make it better than please feel free!

## How it works

So the general steps for the effect is the following...

In your scene you would have objects that have primitive shadow casters on them, these get picked up globally by the camera and a compute buffer is created to contain all of the shapes found (Boxes, Capsules, Spheres).

After that we have 2 cameras that are created, which act as our buffers (not a fan of this currently, looking for a better way to do it). Both cameras render with a shader replacement. One camera renders scene directionality while the other renders a mask buffer for dynamic objects. 

Note: The mask buffer is used during compositing to control self shadowing (or to remove it altogether), objects included in the mask are ones that are not lightmapped. Which is done with a replacement shader that will render black if the LIGHTMAP_ON keyword is on, and will render white if it is off.

It's worth mentioning that light directionality can be sampled from different places, each have their own advantages and drawbacks...
- **Directional Scene Lightmaps:** Using lightmaps baked with directionality to obtain the dominant light direction.
- **Light Probes:** Dominant light direction is obtained by objects shaded through light probes or ambient probes.
- **Global Direction:** A single vector that defines the global direction in which shadows come from.

The last thing that is done is that a camera world position render target is also generated and blitted. Then finally all of this information is fed into a compute shader, tracing each shape against the scene world position buffer to get our result.

After that, we get the resulting render target from that, and do a bilaterial blur (since the tracing is done at a low resolution) to smooth it out. Then it's composited back into the main scene color.

## Future Ideas/Plans

Some things I want to do, and things I would like to get help with...

- VR Support *(MAIN GOAL)*
- Proper Box tracing function
- Replace the dual cameras I use that create my Directionality/Mask buffers with a proper implementation via command buffers or some other way, I'm not happy with the current way I have it.
- Find a way to optimize the shape compute buffers by only updating/rebuilding when necessary (i.e. only updating when shapes have been moved)
- Move the entire effect into a single compute shader for ease.
- Using a stretched elipsoid function for an option to approximate all of the current primitives like Boxes, Capsules, and Spheres for improved performance as proposed in the [first last of us paper](http://miciwan.com/SIGGRAPH2013/Lighting%20Technology%20of%20The%20Last%20Of%20Us.pdf).
- Implement a LUT generation for the cone angle as proposed in the [first last of us paper](http://miciwan.com/SIGGRAPH2013/Lighting%20Technology%20of%20The%20Last%20Of%20Us.pdf).
- A better/more efficent way to obtain shadow casters. Currently grabbing them all globally is a bad idea, perhaps a pre-existing list of shadow casters might help?

## Sources/Credits

Sources that I've used directly (or have helped me indirectly)...

- [ShaderToy: Capsule shadow by romainguy](https://www.shadertoy.com/view/3stcD4)
- [Lighting Technology of The Last of Us Part II](https://history.siggraph.org/learning/lighting-technology-of-the-last-of-us-part-ii-by-doghramachi/)
- [Lighting technology of the last of us](http://miciwan.com/SIGGRAPH2013/Lighting%20Technology%20of%20The%20Last%20Of%20Us.pdf)
- [Extracting dominant light from Spherical Harmonics](https://www.gamedeveloper.com/programming/in-depth-extracting-dominant-light-from-spherical-harmonics)
- [Unity Experimental HDRP Capsule Shadows Fork 1](https://github.com/Unity-Technologies/Graphics/tree/draft/rp/capsule-shadows)
- [Unity Experimental HDRP Capsule Shadows Fork 2](https://github.com/Unity-Technologies/Graphics/tree/9.x.x/backport/hw20/capsule-soft-shadows/com.unity.render-pipelines.high-definition/Runtime/Lighting/CapsuleShadows)
- [Unity Spherical Harmonics CPU Code](https://github.com/keijiro/LightProbeUtility/blob/master/Assets/LightProbeUtility.cs)

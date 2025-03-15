Data structure:
- Engine is the top level struct that encapsulates all other components. It manages the lifetime of all resources and provides a unified interface for interacting with the renderer.
- VulkanContext struct device, surface, ... all things that are persist between frames. it also handles buffer creation and memory management
- Renderer struct encapsulates all frame-level information, such as semaphores, fences, and command buffers
- Mesh structs handle mesh buffer information
- Material structs handle vulkan pipeline and descriptors
- Scene graph are implemented using a tree structure, one node can contains multiple children
- Resource Manager uses generational index to handle resource storage and references

Entity interaction:
- Function begin with `malloc` generally allow a higher level Entity/container to make slot for a new Entity.
- Function named `init` generally allow an Entity to initialize its properties on its own. `init` could take external dependencies as in its function parameters.
- Function begin with `build` generally allow a higher level Entity to facilitate creation of lower level Entity.
In `build` function, the higher level Entity will calculate and set its child's properties.
When an `init` function takes too many dependencies, it should be refactored into a `build` function and let the higher level Entity handle the initialization.
For example `Engine.buildMaterial`, Material itself doesn't have the context to create its own pipeline, it has to rely on Engine to create the pipeline.
After `build` operation, the Entity will be ready to use. `build` operation needs all self contained data to be ready beforehand.
- Function begin with `create` generally encapsulates `malloc`, `init`, and `build`.
- Function named `destroy` generally allow an Entity to release all resources it owns.
- Function named `free` generally allow a container to destroy an Entity it owns and free up resources.

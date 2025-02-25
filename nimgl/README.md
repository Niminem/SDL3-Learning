# NimGL (Nim Graphics Library)

ThreeJS-like 3D Graphics Library in Nim leveraging SDL3.

## 1. Define Core Architecture

Three.js has a well-structured hierarchy and relies on OOP concepts like inheritance. Nim supports OOP but also allows flexible patterns. For performance, you might want to mix OOP with ECS principles later.

Key classes to replicate:

- **Object3D**: The base class for most objects.
- **Scene**: Container for objects.
- **Camera**: Perspective and orthographic cameras.
- **Renderer**: Core rendering logic.
- **Geometry**: Mesh data.
- **Material**: Shader/material management.
- **Mesh**: Combines geometry and material.

Suggested Approach:

Use ref object in Nim for inheritance-based structures (Object3D hierarchy).
Separate rendering, math, scene management, and resources into distinct modules.
Consider a component-based approach for advanced features later (like ECSY in Three.js).

## 2. Math Utilities

Three.js has extensive math support. You'll need equivalents in Nim.

Replicate:

- Vector2, Vector3, Vector4
- Quaternion
- Matrix3, Matrix4
- Euler, Box3, Sphere

Action:

You chose nim-glm — perfect for Vector, Matrix, and Quaternion operations.
Create wrapper functions to mimic Three.js method signatures (e.g., position.add(), matrix.makePerspective()).

## 3. Core 3D Objects & Scene Graph

Three.js uses a scene graph (Object3D parent-child relationships).

Implement:

- Object3D with position, rotation, scale, and transformation matrices.
- Methods like add(), remove(), traverse() for hierarchical relationships.
- Scene class extending Object3D.

Action:

Ensure updateMatrix() and updateMatrixWorld() methods propagate transformations correctly in the graph.

## 4. Renderer Abstraction

The WebGLRenderer in Three.js handles shaders, buffers, and the rendering pipeline. Your version will wrap SDL3 GPU API calls.

Tasks:

- Create GPUDevice, GPUTexture, GPURenderTarget, and buffer abstractions.
- Handle uniform buffers for camera matrices, lights, and materials.
- Implement render passes:
- Scene rendering with depth testing.
- Post-processing pipeline.

Key Step:

Design a Renderer class that takes a Scene and Camera and calls:

`proc render(renderer: Renderer, scene: Scene, camera: Camera)`

This should traverse the scene graph, bind buffers, upload uniforms, and issue draw calls.

## 5. Shaders and Materials

Three.js uses ShaderMaterial, MeshBasicMaterial, MeshPhongMaterial, etc.

Steps:

- Define a Material base type with shader bindings.
- Write GLSL shaders and load them into SDL3 GPU API.
- Create material subclasses with different shading models.

Important:

Implement uniform management to update shader data per frame, including:

- Camera matrices.
- Lighting data.
- Object transformations.

## 6. Geometries and Buffers

Geometries in Three.js are managed by BufferGeometry.

Tasks:

Create a BufferGeometry object to store:
- Vertex buffer.
- Index buffer.
- Attribute buffers (normals, uvs, etc.).

Support loading from files (e.g., .obj, .gltf) later.

Example:

```
type
  BufferGeometry = ref object
    vertices: seq[Vector3]
    indices: seq[int]
    normals: seq[Vector3]
    uvs: seq[Vector2]
```
## 7. Camera Systems

Implement PerspectiveCamera and OrthographicCamera.

Features:

- lookAt() support.
- Perspective matrix calculations.
- Mouse/keyboard-controlled OrbitControls and FirstPersonControls.

## 8. Lights and Shadows

Three.js supports multiple lights (AmbientLight, DirectionalLight, PointLight, etc.).

Tasks:

- Implement light types.
- Add shadow map rendering passes:
- Depth texture generation.
- Shadow sampling in fragment shaders.

## 9. Animation and Interaction

- AnimationMixer-like system for keyframe animations.
- Raycasting for object picking (useful for editors and interaction).
- Event dispatching system (you already have EventDispatcher).

## 10. Asset Loading and Parsing
- Support image textures (png, jpeg).
- Support 3D models (obj, gltf).
- Async asset loading with Nim's async capabilities.

## 11. Performance Considerations
- Batch draw calls where possible.
- Frustum culling (cull objects outside the camera view).
- Level of Detail (LOD) support.
- Efficient uniform updates (group frequently updated uniforms).

## 12. Advanced Features (Later Stage)
- Post-Processing: Effects like bloom, SSAO, and FXAA.
- PBR Materials: For realistic rendering.
- Physics Integration: Bind with Bullet or PhysX.
- VR Support: SDL3 + OpenXR integration.

## Key SDL3 GPU API Areas to Master:
- SDL_RenderGeometry and similar functions.
- Texture creation, binding, and filtering.
- Framebuffer (render target) management.
- GPU buffer allocation and management.

## Development Roadmap Summary:
- Foundation: Math, Object3D, Scene, Camera.
- Rendering Core: Renderer abstraction, shaders, and GPU resources.
- Objects & Materials: Mesh, BufferGeometry, Material subclasses.
- Controls & Interactivity: Camera controls, raycasting.
- Lighting & Shadows: Basic lighting models, shadow maps.
- Performance Optimization: Frustum culling, batching.
- Extra Features: Post-processing, animation system, asset loading.
- Editor Tools (If Desired): A scene editor similar to Three.js Editor.
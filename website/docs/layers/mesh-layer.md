# Mesh Layer

A mesh layer draws lit 3D meshes, such as trees, furniture or any other model,
at real coordinates in the map's 3D view. Fill extrusions can only raise a
polygon into a prism; a mesh layer takes any triangles. MapLibre GL JS apps get
the same with a custom layer that renders three.js meshes; on Android and iOS
the plugin draws them natively.

!!! info "Android and iOS"
    `addMeshLayer` is supported on Android and iOS. On web it throws an
    `UnsupportedError`. On Android it needs MapLibre's OpenGL ES backend, the
    plugin's default: with `maplibre_gl.renderer` set to `vulkan`, or `auto`
    on a device with Vulkan, the layer draws nothing (see
    [Rendering backend](../advanced/performance.md#rendering-backend-android)).

## Basic setup

A `MeshLayerMesh` holds triangles in meters around its origin, x east, y north
and z up: a position, a unit normal and an sRGB color (r, g, b, a in 0 to 1)
per vertex, and three vertex indices per triangle. A `MeshLayerInstance` places
a mesh on the map, with an altitude, a bearing and a scale.

```dart
await controller.addMeshLayer(
  'trees',
  MeshLayer(
    meshes: [tree], // a MeshLayerMesh
    instances: const [
      MeshLayerInstance(mesh: 0, position: LatLng(52.5145, 13.3501)),
      MeshLayerInstance(
        mesh: 0,
        position: LatLng(52.5147, 13.3505),
        bearing: 30,
        scale: 1.2,
      ),
    ],
    minzoom: 14,
  ),
);

// Later
await controller.removeLayer('trees');
```

The layer cannot be changed in place: remove it and add it again.

## What hides the meshes

MapLibre Native does not give a custom layer the depth its fill extrusions are
drawn with, so a mesh layer draws its own 3D scene over the layers below it.
Add it on top. The meshes hide each other, and whatever else should hide them,
such as the walls of an extruded building, goes into the layer as an occluder:
it is only written to the depth, never drawn.

```dart
MeshLayer(
  meshes: [
    tree,
    MeshLayerMesh.occluding(positions: wallPositions, indices: wallIndices),
  ],
  instances: [
    ...trees,
    const MeshLayerInstance(mesh: 1, position: buildingOrigin),
  ],
);
```

## Light

`MeshLayerLight` lights the meshes the way three.js lights a rough
`MeshStandardMaterial`: a hemisphere light between a sky and a ground color and
a directional sun. The defaults are a white sky, a green grey ground and a sun
from the upper south west.

## Performance

Each mesh is uploaded to the GPU once and drawn for all its instances in one
instanced draw call, so thousands of trees cost little more than one. Per frame
the renderer computes a single matrix, in double precision around the layer's
first instance, so the meshes stay steady at high zoom levels.

The example app's *Mesh Layer* page places 200, 2,000 or 20,000 trees next to an
extruded building.

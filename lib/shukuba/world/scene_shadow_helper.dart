import 'package:flutter_scene/scene.dart' show Node;

/// Recursively marks [node] and all its descendants with [shadowStatic].
///
/// In `flutter_scene`, `Node.shadowStatic` is evaluated per mesh-bearing node
/// and is not inherited down parent-child node hierarchies. This helper
/// traverses the entire subtree to ensure all static geometry (including both
/// `MeshComponent` and `InstancedMeshComponent`) participates in persistent
/// shadow map tile caching.
Node markSubtreeShadowStatic(Node node, {bool shadowStatic = true}) {
  node.shadowStatic = shadowStatic;
  for (final child in node.children) {
    markSubtreeShadowStatic(child, shadowStatic: shadowStatic);
  }
  return node;
}

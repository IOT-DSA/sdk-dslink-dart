/// Helper Nodes for Responders
library dslink.nodes;

import "package:dslink/common.dart";
import "package:dslink/responder.dart";

/// An Action for Deleting a Given Node
class DeleteActionNode extends SimpleNode {
  final String targetPath;
  final SimpleNodeProvider provider;

  /// When this action is invoked, [provider.removeNode] will be called with [targetPath].
  DeleteActionNode(String path, this.provider, this.targetPath) : super(path);

  /// When this action is invoked, [provider.removeNode] will be called with the parent of this action.
  DeleteActionNode.forParent(String path, NodeProvider provider) :
    this(path, provider, new Path(path).parentPath);

  /// Handles an action invocation and deletes the target path.
  @override
  Object onInvoke(Map<String, dynamic> params) {
    provider.removeNode(targetPath);
    return {};
  }
}

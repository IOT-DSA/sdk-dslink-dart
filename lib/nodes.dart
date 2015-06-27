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
  DeleteActionNode.forParent(String path, NodeProvider provider)
      : this(path, provider, new Path(path).parentPath);

  /// Handles an action invocation and deletes the target path.
  @override
  Object onInvoke(Map<String, dynamic> params) {
    provider.removeNode(targetPath);
    return {};
  }
}

/// A function that is called when an action is invoked.
typedef ActionFunction(Map<String, dynamic> params);

/// A Simple Action Node
class SimpleActionNode extends SimpleNode {
  final ActionFunction function;

  /// When this action is invoked, the given [function] will be called with the parameters
  /// and then the result of the function will be returned.
  SimpleActionNode(String path, this.function) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) => function(params);
}

/// A Node Provider for a Single Node
class SingleNodeProvider extends NodeProvider {
  final LocalNode node;

  SingleNodeProvider(this.node);

  @override
  LocalNode getNode(String path) => node;
  IPermissionManager permissions = new DummyPermissionManager();

  Responder createResponder(String dsId) {
    return new Responder(this, dsId);
  }
}

typedef void NodeUpgradeFunction(int from);

class UpgradableNode extends SimpleNode {
  final int latestVersion;
  final NodeUpgradeFunction upgrader;

  UpgradableNode(String path, this.latestVersion, this.upgrader) : super(path);

  @override
  void onCreated() {
    if (configs.containsKey(r"$version")) {
      var version = configs[r"$version"];
      if (version != latestVersion) {
        upgrader(version);
        configs[r"$version"] = latestVersion;
      }
    } else {
      configs[r"$version"] = latestVersion;
    }
  }
}

typedef void SimpleCallback();
typedef void ChildChangedCallback(String name, Node node);
typedef SimpleNode LoadChildCallback(
    String name, Map data, SimpleNodeProvider provider);

/// A Simple Node which delegates all basic methods to given functions.
class CallbackNode extends SimpleNode {
  final SimpleCallback onCreatedCallback;
  final SimpleCallback onRemovingCallback;
  final ChildChangedCallback onChildAddedCallback;
  final ChildChangedCallback onChildRemovedCallback;
  final ActionFunction onActionInvoke;
  final LoadChildCallback onLoadChildCallback;

  CallbackNode(String path,
      {this.onActionInvoke,
      ChildChangedCallback onChildAdded,
      ChildChangedCallback onChildRemoved,
      SimpleCallback onCreated,
      SimpleCallback onRemoving,
      LoadChildCallback onLoadChild})
      : super(path),
        onChildAddedCallback = onChildAdded,
        onChildRemovedCallback = onChildRemoved,
        onCreatedCallback = onCreated,
        onRemovingCallback = onRemoving,
        onLoadChildCallback = onLoadChild;

  @override
  onInvoke(Map<String, dynamic> params) {
    if (onActionInvoke != null) {
      return onActionInvoke(params);
    } else {
      return super.onInvoke(params);
    }
  }

  @override
  void onCreated() {
    if (onCreatedCallback != null) {
      onCreatedCallback();
    }
  }

  @override
  void onRemoving() {
    if (onRemovingCallback != null) {
      onRemovingCallback();
    }
  }

  @override
  void onChildAdded(String name, Node node) {
    if (onChildAddedCallback != null) {
      onChildAddedCallback(name, node);
    }
  }

  @override
  void onChildRemoved(String name, Node node) {
    if (onChildRemovedCallback != null) {
      onChildRemovedCallback(name, node);
    }
  }

  @override
  SimpleNode onLoadChild(String name, Map data, SimpleNodeProvider provider) {
    if (onLoadChildCallback != null) {
      return onLoadChildCallback(name, data, provider);
    } else {
      return super.onLoadChild(name, data, provider);
    }
  }
}

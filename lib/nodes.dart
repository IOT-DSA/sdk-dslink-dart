/// Helper Nodes for Responders
library dslink.nodes;

import "dart:async";
import "dart:convert";

import "package:dslink/common.dart";
import "package:dslink/responder.dart";

import "package:json_diff/json_diff.dart" as JsonDiff;

import "package:dslink/utils.dart" show Producer;

part "src/nodes/json.dart";

/// An Action for Deleting a Given Node
class DeleteActionNode extends SimpleNode {
  final String targetPath;
  final Function onDelete;

  /// When this action is invoked, [provider.removeNode] will be called with [targetPath].
  DeleteActionNode(String path, MutableNodeProvider provider, this.targetPath, {
    this.onDelete
  }) : super(path, provider);

  /// When this action is invoked, [provider.removeNode] will be called with the parent of this action.
  DeleteActionNode.forParent(String path, MutableNodeProvider provider, {
    Function onDelete
  }) : this(path, provider, new Path(path).parentPath, onDelete: onDelete);

  /// Handles an action invocation and deletes the target path.
  @override
  Object onInvoke(Map<String, dynamic> params) {
    provider.removeNode(targetPath);
    if (onDelete != null) {
      onDelete();
    }
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
  SimpleActionNode(String path, this.function, [SimpleNodeProvider provider]) : super(path, provider);

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

  Responder createResponder(String dsId, String sessionId) {
    return new Responder(this, dsId);
  }

  LocalNode getOrCreateNode(String path, [bool addToTree = true]) {
    return node;
  }
}

typedef void NodeUpgradeFunction(int from);

class UpgradableNode extends SimpleNode {
  final int latestVersion;
  final NodeUpgradeFunction upgrader;

  UpgradableNode(String path, this.latestVersion, this.upgrader, [SimpleNodeProvider provider]) : super(path, provider);

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

/// A Lazy Value Node
class LazyValueNode extends SimpleNode {
  SimpleCallback onValueSubscribe;
  SimpleCallback onValueUnsubscribe;

  LazyValueNode(String path, {
    SimpleNodeProvider provider,
    this.onValueSubscribe,
    this.onValueUnsubscribe
  }) : super(path, provider);

  @override
  onSubscribe() {
    subscriptionCount++;
    checkSubscriptionNeeded();
  }

  @override
  onUnsubscribe() {
    subscriptionCount--;
    checkSubscriptionNeeded();
  }

  checkSubscriptionNeeded() {
    if (subscriptionCount <= 0) {
      subscriptionCount = 0;
      onValueUnsubscribe();
    } else {
      onValueSubscribe();
    }
  }

  int subscriptionCount = 0;
}

/// Represents a Simple Callback Function
typedef void SimpleCallback();

/// Represents a function that is called when a child node has changed.
typedef void ChildChangedCallback(String name, Node node);

/// Represents a function that is called on a node when a child is loading.
typedef SimpleNode LoadChildCallback(
    String name, Map data, SimpleNodeProvider provider);

typedef Future ResolveNodeHandler(CallbackNode node);

class ResolvingNodeProvider extends SimpleNodeProvider {
  ResolveNodeHandler handler;

  ResolvingNodeProvider([Map<String, dynamic> defaultNodes, Map<String, NodeFactory> profiles]) :
        super(defaultNodes, profiles);

  @override
  LocalNode getNode(String path, {Completer<CallbackNode> onLoaded, bool forceHandle: false}) {
    LocalNode node = super.getNode(path);
    if (path != "/" && node != null && !forceHandle) {
      if (onLoaded != null && !onLoaded.isCompleted) {
        onLoaded.complete(node);
      }
      return node;
    }

    if (handler == null) {
      if (onLoaded != null && !onLoaded.isCompleted) {
        onLoaded.complete(null);
      }
      return null;
    }

    Completer c = new Completer();
    CallbackNode n = new CallbackNode(path, provider: this);
    n.onLoadedCompleter = c;
    bool isListReady = false;
    n.isListReady = () => isListReady;
    handler(n).then((m) {
      if (!m) {
        isListReady = true;
        String ts = ValueUpdate.getTs();
        n.getDisconnectedStatus = () => ts;
        n.listChangeController.add(r"$is");

        if (onLoaded != null && !onLoaded.isCompleted) {
          onLoaded.complete(n);
        }

        if (c != null && !c.isCompleted) {
          c.complete();
        }

        return;
      }
      isListReady = true;
      n.listChangeController.add(r"$is");
      if (onLoaded != null && !onLoaded.isCompleted) {
        onLoaded.complete(n);
      }

      if (c != null && !c.isCompleted) {
        c.complete();
      }
    }).catchError((e, stack) {
      isListReady = true;
      String ts = ValueUpdate.getTs();
      n.getDisconnectedStatus = () => ts;
      n.listChangeController.add(r"$is");

      if (c != null && !c.isCompleted) {
        c.completeError(e, stack);
      }
    });
    return n;
  }

  @override
  SimpleNode addNode(String path, Map m) {
    if (path == '/' || !path.startsWith('/')) return null;

    Path p = new Path(path);
    SimpleNode pnode = getNode(p.parentPath);

    SimpleNode node;

    if (pnode != null) {
      node = pnode.onLoadChild(p.name, m, this);
    }

    if (node == null) {
      String profile = m[r'$is'];
      if (profileMap.containsKey(profile)) {
        node = profileMap[profile](path);
      } else {
        node = new CallbackNode(path);
      }
    }

    nodes[path] = node;
    node.load(m);

    node.onCreated();

    if (pnode != null) {
      pnode.children[p.name] = node;
      pnode.onChildAdded(p.name, node);
      pnode.updateList(p.name);
    }

    return node;
  }

  @override
  LocalNode getOrCreateNode(String path, [bool addToTree = true, bool init = true]) => getNode(path);
}

/// A Simple Node which delegates all basic methods to given functions.
class CallbackNode extends SimpleNode implements WaitForMe {
  SimpleCallback onCreatedCallback;
  SimpleCallback onRemovingCallback;
  ChildChangedCallback onChildAddedCallback;
  ChildChangedCallback onChildRemovedCallback;
  ActionFunction onActionInvoke;
  LoadChildCallback onLoadChildCallback;
  SimpleCallback onSubscribeCallback;
  SimpleCallback onUnsubscribeCallback;
  Producer<bool> isListReady;
  Producer<String> getDisconnectedStatus;
  SimpleCallback onAllListCancelCallback;
  SimpleCallback onListStartListen;
  Completer onLoadedCompleter;

  CallbackNode(String path,
      {SimpleNodeProvider provider,
        this.onActionInvoke,
      ChildChangedCallback onChildAdded,
      ChildChangedCallback onChildRemoved,
      SimpleCallback onCreated,
      SimpleCallback onRemoving,
      LoadChildCallback onLoadChild,
      SimpleCallback onSubscribe,
      SimpleCallback onUnsubscribe})
      : onChildAddedCallback = onChildAdded,
        onChildRemovedCallback = onChildRemoved,
        onCreatedCallback = onCreated,
        onRemovingCallback = onRemoving,
        onLoadChildCallback = onLoadChild,
        onSubscribeCallback = onSubscribe,
        onUnsubscribeCallback = onUnsubscribe,
        super(path, provider);

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

  @override
  onSubscribe() {
    if (onSubscribeCallback != null) {
      return onSubscribeCallback();
    }
  }

  @override
  Future get onLoaded {
    if (onLoadedCompleter != null) {
      return onLoadedCompleter.future;
    } else {
      return new Future.sync(() => null);
    }
  }

  @override
  onUnsubscribe() {
    if (onUnsubscribeCallback != null) {
      return onUnsubscribeCallback();
    }
  }

  @override
  bool get listReady {
    if (isListReady != null) {
      return isListReady();
    } else {
      return true;
    }
  }

  @override
  String get disconnected {
    if (getDisconnectedStatus != null) {
      return getDisconnectedStatus();
    } else {
      return null;
    }
  }

  @override
  onStartListListen() {
    if (onListStartListen != null) {
      onListStartListen();
    }
    super.onStartListListen();
  }

  @override
  onAllListCancel() {
    if (onAllListCancelCallback != null) {
      onAllListCancelCallback();
    }
    super.onAllListCancel();
  }
}

class NodeNamer {
  static final List<String> BANNED_CHARS = [
    r"%",
    r".",
    r"/",
    r"\",
    r"?",
    r"*",
    r":",
    r"|",
    r"<",
    r">",
    r"$",
    r"@"
  ];

  static String createName(String input) {
    var out = new StringBuffer();
    cu(String n) => const Utf8Encoder().convert(n)[0];
    mainLoop: for (var i = 0; i < input.length; i++) {
      String char = input[i];

      if (char == "%" && (i + 1 < input.length)) {
        String hexA = input[i + 1];
        if ((cu(hexA) >= cu("0") && cu(hexA) <= cu("9")) ||
            (cu(hexA) >= cu("a") && cu(hexA) <= cu("f")) ||
            (cu(hexA) >= cu("A") && cu(hexA) <= cu("F"))
          ) {
          if (i + 2 < input.length) {
            String hexB = input[i + 2];
            if ((cu(hexB) > cu("0") && cu(hexB) <= cu("9")) ||
                (cu(hexB) >= cu("a") && cu(hexB) <= cu("f")) ||
                (cu(hexB) >= cu("A") && cu(hexB) <= cu("F"))
            ) {
              i += 2;
              out.write("%");
              out.write(hexA);
              out.write(hexB);
              continue;
            } else {
              ++i;
              out.write("%${hexA}");
              continue;
            }
          }
        }
      }

      for (String bannedChar in BANNED_CHARS) {
        if (char == bannedChar) {
          var e = char.codeUnitAt(0).toRadixString(16);
          out.write("%${e}");
          continue mainLoop;
        }
      }

      out.write(char);
    }
    return out.toString();
  }

  static String decodeName(String input) {
    var out = new StringBuffer();
    cu(String n) => const Utf8Encoder().convert(n)[0];
    mainLoop: for (var i = 0; i < input.length; i++) {
      String char = input[i];

      if (char == "%") {
        String hexA = input[i + 1];
        if ((cu(hexA) >= cu("0") && cu(hexA) <= cu("9")) ||
            (cu(hexA) >= cu("a") && cu(hexA) <= cu("f")) ||
            (cu(hexA) >= cu("A") && cu(hexA) <= cu("F"))
        ) {
          String s = hexA;

          if (i + 2 < input.length) {
            String hexB = input[i + 2];
            if ((cu(hexB) > cu("0") && cu(hexB) <= cu("9")) ||
                (cu(hexB) >= cu("a") && cu(hexB) <= cu("f")) ||
                (cu(hexB) >= cu("A") && cu(hexB) <= cu("F"))
            ) {
              ++i;
              s += hexB;
            }
          }

          int c = int.parse(s, radix: 16);
          out.writeCharCode(c);
          i++;
          continue;
        }
      }

      out.write(char);
    }

    return out.toString();
  }

  static String joinWithGoodName(String p, String name) {
    return new Path(p).child(NodeNamer.createName(name)).path;
  }
}

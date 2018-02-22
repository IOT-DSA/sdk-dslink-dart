part of dslink.responder;

/// Interface for node providers that are serializable.
abstract class SerializableNodeProvider {
  /// Initialize the node provider.
  void init([Map<String, dynamic> m, Map<String, NodeFactory> profiles]);

  /// Save the node provider to a map.
  Map save();

  /// Persist the node provider.
  void persist([bool now = false]);
}

/// Interface for node providers that are mutable.
abstract class MutableNodeProvider {
  /// Updates the value of the node at [path] to the given [value].
  void updateValue(String path, Object value);
  /// Adds a node at the given [path] that is initialized with the given data in [m].
  LocalNode addNode(String path, Map m);
  /// Removes the node specified at [path].
  void removeNode(String path);
  /// Add a profile to the node provider.
  void addProfile(String name, NodeFactory factory);
}

class SimpleNodeProvider extends NodeProviderImpl
    implements SerializableNodeProvider, MutableNodeProvider {
  /// Global instance.
  /// This is by default always the first instance of [SimpleNodeProvider].
  static SimpleNodeProvider instance;

  ExecutableFunction _persist;
  IconResolver _iconResolver;

  /// All the nodes in this node provider.
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  List<SimpleNodeFactory> _resolverFactories = [];

  @override
  LocalNode getNode(String path) {
    return _getNode(path);
  }

  void setIconResolver(IconResolver resolver) {
    _iconResolver = resolver;

    nodes["/sys/getIcon"] = new SysGetIconNode("/sys/getIcon", this);
  }

  LocalNode _getNode(String path, {bool allowStubs: false}) {
    SimpleNode node = nodes[path];

    if (node != null && (!node._stub || allowStubs)) {
      return node;
    }

    if (_resolverFactories.isNotEmpty) {
      for (var f in _resolverFactories) {
        var node = f(path);
        if (node != null) {
          return node;
        }
      }
    }

    return null;
  }

  /// Gets a node at the given [path] if it exists.
  /// If it does not exist, create a new node and return it.
  ///
  /// When [addToTree] is false, the node will not be inserted into the node provider.
  /// When [init] is false, onCreated() is not called.
  LocalNode getOrCreateNode(String path, [bool addToTree = true, bool init = true]) {
    LocalNode node = _getNode(path, allowStubs: true);

    if (node != null) {
      if (addToTree) {
        Path po = new Path(path);
        if (!po.isRoot) {
          LocalNode parent = getNode(po.parentPath);

          if (parent != null && !parent.children.containsKey(po.name)) {
            parent.addChild(po.name, node);
            parent.listChangeController.add(po.name);
            node.listChangeController.add(r"$is");
          }
        }

        if (node is SimpleNode) {
          node._stub = false;
        }
      }

      return node;
    }

    if (addToTree) {
      return createNode(path, init);
    } else {
      node = new SimpleNode(path, this)
        .._stub = true;
      nodes[path] = node;
      return node;
    }
  }

  /// Checks if this provider has the node at [path].
  bool hasNode(String path) {
    SimpleNode node = nodes[path];

    if (node == null) {
      return false;
    }

    if (node.isStubNode == true) {
      return false;
    }

    return true;
  }

  void registerResolver(SimpleNodeFactory factory) {
    if (!_resolverFactories.contains(factory)) {
      _resolverFactories.add(factory);
    }
  }

  void unregisterResolver(SimpleNodeFactory factory) {
    _resolverFactories.remove(factory);
  }

  @override
  void addProfile(String name, NodeFactory factory) {
    _profiles[name] = factory;
  }

  /// Sets the function that persists the nodes.
  void setPersistFunction(ExecutableFunction doPersist) {
    _persist = doPersist;
  }

  /// Persist the nodes in this provider.
  /// If you are not using a LinkProvider, then call [setPersistFunction] to set
  /// the function that is called to persist.
  void persist([bool now = false]) {
    if (now) {
      if (_persist == null) {
        return;
      }

      _persist();
    } else {
      new Future.delayed(const Duration(seconds: 5), () {
        if (_persist == null) {
          return;
        }

        _persist();
      });
    }
  }

  /// Creates a node at [path].
  /// If a node already exists at this path, an exception is thrown.
  /// If [init] is false, onCreated() is not called.
  SimpleNode createNode(String path, [bool init = true]) {
    Path p = new Path(path);
    LocalNode existing = nodes[path];

    if (existing != null) {
      if (existing is SimpleNode) {
        if (existing._stub != true) {
          throw new Exception("Node at ${path} already exists.");
        } else {
          existing._stub = false;
        }
      } else {
        throw new Exception("Node at ${path} already exists.");
      }
    }

    SimpleNode node = existing == null ? new SimpleNode(path, this) : existing;
    nodes[path] = node;

    if (init) {
      node.onCreated();
    }

    SimpleNode pnode;

    if (p.parentPath != "") {
      pnode = getNode(p.parentPath);
    }

    if (pnode != null) {
      pnode.children[p.name] = node;
      pnode.onChildAdded(p.name, node);
      pnode.updateList(p.name);
    }

    return node;
  }

  /// Creates a [SimpleNodeProvider].
  /// If [m] and optionally [profiles] is specified,
  /// the provider is initialized with these values.
  SimpleNodeProvider([Map<String, dynamic> m, Map<String, NodeFactory> profiles]) {
    // by default, the first SimpleNodeProvider is the static instance
    if (instance == null) {
      instance = this;
    }

    root = new SimpleNode("/", this);
    nodes["/"] = root;
    defs = new SimpleHiddenNode('/defs', this);
    nodes[defs.path] = defs;
    sys = new SimpleHiddenNode('/sys', this);
    nodes[sys.path] = sys;

    init(m, profiles);
  }

  /// Root node
  SimpleNode root;

  /// defs node
  SimpleHiddenNode defs;

  /// sys node
  SimpleHiddenNode sys;

  @override
  void init([Map<String, dynamic> m, Map<String, NodeFactory> profiles]) {
    if (profiles != null) {
      if (profiles.isNotEmpty) {
        _profiles.addAll(profiles);
      } else {
        _profiles = profiles;
      }
    }

    if (m != null) {
      root.load(m);
    }
  }

  Map<String, NodeFactory> get profileMap => _profiles;

  @override
  Map save() {
    return root.save();
  }

  @override
  void updateValue(String path, Object value) {
    SimpleNode node = getNode(path);
    node.updateValue(value);
  }

  /// Sets the given [node] to the given [path].
  void setNode(String path, SimpleNode node, {bool registerChildren: false}) {
    if (path == '/' || !path.startsWith('/')) return null;
    Path p = new Path(path);
    SimpleNode pnode = getNode(p.parentPath);

    nodes[path] = node;

    node.onCreated();

    if (pnode != null) {
      pnode.children[p.name] = node;
      pnode.onChildAdded(p.name, node);
      pnode.updateList(p.name);
    }

    if (registerChildren) {
      for (SimpleNode c in node.children.values) {
        setNode(c.path, c);
      }
    }
  }

  @override
  SimpleNode addNode(String path, Map m) {
    if (path == '/' || !path.startsWith('/')) return null;

    Path p = new Path(path);
    SimpleNode oldNode = _getNode(path, allowStubs: true);

    SimpleNode pnode = getNode(p.parentPath);
    SimpleNode node;

    if (pnode != null) {
      node = pnode.onLoadChild(p.name, m, this);
    }

    if (node == null) {
      String profile = m[r'$is'];
      if (_profiles.containsKey(profile)) {
        node = _profiles[profile](path);
      } else {
        node = getOrCreateNode(path, true, false);
      }
    }

    if (oldNode != null) {
      logger.fine("Found old node for ${path}: Copying subscriptions.");

      for (ValueUpdateCallback func in oldNode.callbacks.keys) {
        node.subscribe(func, oldNode.callbacks[func]);
      }

      if (node is SimpleNode) {
        try {
          node._listChangeController = oldNode._listChangeController;
          node._listChangeController.onStartListen = () {
            node.onStartListListen();
          };
          node._listChangeController.onAllCancel = () {
            node.onAllListCancel();
          };
        } catch (e) {}

        if (node._hasListListener) {
          node.onStartListListen();
        }
      }
    }

    nodes[path] = node;
    node.load(m);
    node.onCreated();

    if (pnode != null) {
      pnode.addChild(p.name, node);
      pnode.onChildAdded(p.name, node);
      pnode.updateList(p.name);
    }

    node.updateList(r"$is");

    if (oldNode != null) {
      oldNode.updateList(r"$is");
    }

    return node;
  }

  @override
  void removeNode(String path, {bool recurse: true}) {
    if (path == '/' || !path.startsWith('/')) return;
    SimpleNode node = getNode(path);

    if (node == null) {
      return;
    }

    if (recurse) {
      String base = path;
      if (!base.endsWith("/")) {
        base += "/";
      }

      int baseSlashFreq = countCharacterFrequency(base, "/");

      List<String> targets = nodes.keys.where((String x) {
        return x.startsWith(base) &&
            baseSlashFreq == countCharacterFrequency(x, "/");
      }).toList();

      for (String target in targets) {
        removeNode(target);
      }
    }

    Path p = new Path(path);
    SimpleNode pnode = getNode(p.parentPath);
    node.onRemoving();
    node.removed = true;

    if (pnode != null) {
      pnode.children.remove(p.name);
      pnode.onChildRemoved(p.name, node);
      pnode.updateList(p.name);
    }

    if (node.callbacks.isEmpty && !node._hasListListener) {
      nodes.remove(path);
    } else {
      node._stub = true;
    }
  }

  Map<String, NodeFactory> _profiles = new Map<String, NodeFactory>();

  /// Permissions
  IPermissionManager permissions = new DummyPermissionManager();

  /// Creates a responder with the given [dsId].
  Responder createResponder(String dsId, String sessionId) {
    return new Responder(this, dsId);
  }

  @override
  String toString({bool showInstances: false}) {
    var buff = new StringBuffer();

    void doNode(LocalNode node, [int depth = 0]) {
      Path p = new Path(node.path);
      buff.write("${'  ' * depth}- ${p.name}");

      if (showInstances) {
        buff.write(": ${node}");
      }

      buff.writeln();
      for (var child in node.children.values) {
        doNode(child, depth + 1);
      }
    }

    doNode(root);
    return buff.toString().trim();
  }
}

class SysGetIconNode extends SimpleNode {
  SysGetIconNode(String path, [SimpleNodeProvider provider]) : super(
      path,
      provider
  ) {
    configs.addAll({
      r"$invokable": "read",
      r"$params": [
        {
          "name": "Icon",
          "type": "string"
        }
      ],
      r"$columns": [
        {
          "name": "Data",
          "type": "binary"
        }
      ],
      r"$result": "table"
    });
  }

  @override
  onInvoke(Map<String, dynamic> params) async {
    String name = params["Icon"];
    IconResolver resolver = provider._iconResolver;

    ByteData data = await resolver(name);

    return [[
      data
    ]];
  }
}

part of dslink.responder;

typedef SimpleNode _NodeFactory(String path);

class SimpleTableResult {
  List columns;
  List rows;

  SimpleTableResult([this.rows, this.columns]);
}

class AsyncTableResult {
  InvokeResponse response;
  List columns;
  List rows;
  String status = StreamStatus.initialize;

  AsyncTableResult([this.columns]);

  void update(List rows, [String stat]) {
    if (this.rows == null) {
      this.rows = rows;
    } else {
      this.rows.addAll(rows);
    }

    if (stat != null) {
      status = stat;
    }
    write();
  }

  void write([InvokeResponse resp]) {
    if (resp != null) {
      if (response == null) {
        response = resp;
      } else {
        printWarning('warning, can not use same AsyncTableResult twice');
      }
    }

    if (response != null && (rows != null || status == StreamStatus.closed)) {
      response.updateStream(rows, columns: columns, streamStatus: status);
      rows = null;
      columns = null;
    }
  }

  void close() {
    if (response != null) {
      response.close();
    } else {
      status = StreamStatus.closed;
    }
  }
}

class SimpleNodeProvider extends NodeProviderImpl {
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  LocalNode getNode(String path) {
    if (nodes.containsKey(path)) {
      return nodes[path];
    }
    var node = new SimpleNode(path);
    nodes[path] = node;
    return node;
  }

  SimpleNodeProvider([Map m, Map profiles]) {
    init(m, profiles);
  }
  
  SimpleNode get root => getNode("/");

  void init([Map m, Map profiles]) {
    if (profiles != null) {
      _registerProfiles(profiles);
    }
    
    if (m != null) {
      root.load(m, this);
    }
  }

  Map save() {
    return root.save();
  }

  void updateValue(String path, Object value) {
    SimpleNode node = getNode(path);
    node.updateValue(value);
  }

  LocalNode addNode(String path, Map m) {
    if (path == '/' || !path.startsWith('/')) return;

    Path p = new Path(path);
    SimpleNode pnode = getNode(p.parentPath);

    SimpleNode node = pnode.onLoadChild(p.name, m, this);
    if (node == null) {
      String profile = m[r'$is'];
      if (_profileFactories.containsKey(profile)) {
        node = _profileFactories[profile](path);
      } else {
        node = getNode(path);
      }
    }
    
    nodes[path] = node;
    node.load(m, this);

    node.onCreated();
    pnode.children[p.name] = node;
    pnode.onChildAdded(p.name, node);
    pnode.updateList(p.name);
    
    return node;
  }

  void removeNode(String path) {
    if (path == '/' || !path.startsWith('/')) return;
    SimpleNode node = getNode(path);
    node.onRemoving();
    node.removed = true;
    Path p = new Path(path);
    SimpleNode pnode = getNode(p.parentPath);
    pnode.children.remove(p.name);
    pnode.onChildRemoved(p.name, node);
    pnode.updateList(p.name);
  }

  Map<String, _NodeFactory> _profileFactories = new Map<String, _NodeFactory>();

  void _registerProfiles(Map m) {
    m.forEach((key, val) {
      if (key is String && val is _NodeFactory) {
        _profileFactories[key] = val;
      }
    });
  }
}

class SimpleNode extends LocalNodeImpl {
  SimpleNode(String path) : super(path);

  bool removed = false;

  void load(Map m, NodeProviderImpl provider) {
    if (_loaded) {
      configs.clear();
      attributes.clear();
      children.clear();
    }
    String childPathPre;
    if (path == '/') {
      childPathPre = '/';
    } else {
      childPathPre = '$path/';
    }
    m.forEach((String key, value) {
      if (key.startsWith('?')) {
        if (key == '?value') {
          updateValue(value);
        }
      } else if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        String childPathpath = '$childPathPre$key';
        (provider as SimpleNodeProvider).addNode(childPathpath, value);
        // Node node = provider.getNode('$childPathPre$key');
        // children[key] = node;
        // if (node is LocalNodeImpl) {
        //   node.load(value, provider);
        // }
      }
    });
    _loaded = true;
  }


  Map save() {
    Map rslt = {};
    configs.forEach((str, val) {
      rslt[str] = val;
    });
    attributes.forEach((str, val) {
      rslt[str] = val;
    });

    if (_lastValueUpdate != null && _lastValueUpdate.value != null) {
      rslt['?value'] = _lastValueUpdate.value;
    }

    children.forEach((str, Node node) {
      if (node is SimpleNode) rslt[str] = node.save();
    });

    return rslt;
  }

  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    Object rslt = onInvoke(params);

    if (rslt is Iterable) {
      response.updateStream(rslt.toList(), streamStatus: StreamStatus.closed);
    } else if (rslt is Map) {
      response.updateStream([rslt], streamStatus: StreamStatus.closed);
    } else if (rslt is SimpleTableResult) {
      response.updateStream(rslt.rows, columns: rslt.columns, streamStatus: StreamStatus.closed);
    } else if (rslt is AsyncTableResult) {
      rslt.write(response);
      return response;
    } else if (rslt is Future) {
      var r = new AsyncTableResult();
      rslt.then((value) {
        r.update(value is Iterable ? value.toList() : [value]);
        r.close();
      });
      r.write(response);
      return response;
    } else {
      response.close();
    }

    return response;
  }

  Object onInvoke(Map params) {
    return null;
  }

  /// after node is created
  void onCreated() {
  }

  /// before node gets removed
  void onRemoving() {
  }

  /// after child node is removed
  void onChildRemoved(String name, Node node) {
  }

  /// after child node is created
  void onChildAdded(String name, Node node) {
  }

  /// override default node creation logic for children
  SimpleNode onLoadChild(String name, Map data, SimpleNodeProvider provider) {
    return null;
  }
}

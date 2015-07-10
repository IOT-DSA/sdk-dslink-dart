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
  Map meta;
  OnInvokeClosed onClose;

  AsyncTableResult([this.columns]);

  void update(List rows, [String stat, Map meta]) {
    if (this.rows == null) {
      this.rows = rows;
    } else {
      this.rows.addAll(rows);
    }
    this.meta = meta;
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
        logger.warning("can not use same AsyncTableResult twice");
      }
    }

    if (response != null && (rows != null || status == StreamStatus.closed)) {
      response.updateStream(rows, columns: columns, streamStatus: status, meta:meta);
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

abstract class SerializableNodeProvider {
  void init([Map m, Map profiles]);
  Map save();
}

abstract class MutableNodeProvider {
  void updateValue(String path, Object value);
  LocalNode addNode(String path, Map m);
  void removeNode(String path);
}

class SimpleNodeProvider extends NodeProviderImpl
    implements SerializableNodeProvider, MutableNodeProvider {
  static SimpleNodeProvider instance;

  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  @override
  LocalNode getNode(String path) {
    if (nodes.containsKey(path)) {
      return nodes[path];
    }
    var node = new SimpleNode(path, this);
    nodes[path] = node;
    return node;
  }

  SimpleNodeProvider([Map m, Map profiles]) {
    // by defaut, the first SimpleNodeProvider is the static instance
    if (instance == null) {
       instance = this;
    }
     
    root = getNode("/");
    defs = new SimpleHiddenNode('/defs', this);
    nodes['/defs'] = defs;
    sys = new SimpleHiddenNode('/sys', this);
    nodes['/sys'] = sys;
    
    
    init(m, profiles);
  }

  SimpleNode root;
  SimpleHiddenNode defs;
  SimpleHiddenNode sys;
  
  @override
  void init([Map m, Map profiles]) {
    if (profiles != null) {
      _registerProfiles(profiles);
    }

    if (m != null) {
      root.load(m);
    }
  }

  @override
  Map save() {
    return root.save();
  }

  @override
  void updateValue(String path, Object value) {
    SimpleNode node = getNode(path);
    node.updateValue(value);
  }

  @override
  LocalNode addNode(String path, Map m) {
    if (path == '/' || !path.startsWith('/')) return null;

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
    node.load(m);

    node.onCreated();
    pnode.children[p.name] = node;
    pnode.onChildAdded(p.name, node);
    pnode.updateList(p.name);

    return node;
  }

  @override
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

  IPermissionManager permissions = new DummyPermissionManager();

  Responder createResponder(String dsId) {
    return new Responder(this, dsId);
  }
}

/// A Simple Node Implementation
/// A flexible node implementation that should fit most use cases.
class SimpleNode extends LocalNodeImpl {
  final SimpleNodeProvider provider;
  SimpleNode(String path, [SimpleNodeProvider nodeprovider]) : super(path)
    ,provider = nodeprovider == null? SimpleNodeProvider.instance:nodeprovider;

  bool removed = false;

  /// Load this node from the provided map as [m].
  void load(Map m) {
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
        String childPath = '$childPathPre$key';
        provider.addNode(childPath, value);
        // Node node = provider.getNode('$childPathPre$key');
        // children[key] = node;
        // if (node is LocalNodeImpl) {
        //   node.load(value, provider);
        // }
      }
    });
    _loaded = true;
  }

  /// Save this node into a map.
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

  InvokeResponse invoke(Map params, Responder responder,
      InvokeResponse response, LocalNode parentNode,
      [int maxPermission = Permission.CONFIG]) {
    Object rslt;
    try {
      rslt = onInvoke(params);
    } catch (e, stack) {
      var error = new DSError("invokeException", msg: e.toString());
      try {
        error.detail = stack.toString();
      } catch (e) {}
      response.close(error);
      return error;
    }

    var rtype = "values";
    if (configs.containsKey(r"$result")) {
      rtype = configs[r"$result"];
    }

    if (rslt == null) {
      // Create a default result based on the result type
      if (rtype == "values") {
        rslt = {};
      } else if (rtype == "table") {
        rtype = [];
      } else if (rtype == "stream") {
        rtype = [];
      }
    }

    if (rslt is Iterable) {
      response.updateStream(rslt.toList(), streamStatus: StreamStatus.closed);
    } else if (rslt is Map) {
      response.updateStream([rslt], streamStatus: StreamStatus.closed);
    } else if (rslt is SimpleTableResult) {
      response.updateStream(rslt.rows,
          columns: rslt.columns, streamStatus: StreamStatus.closed);
    } else if (rslt is AsyncTableResult) {
      (rslt as AsyncTableResult).write(response);
      response.onClose = (var response){
        if ((rslt as AsyncTableResult).onClose != null){
          (rslt as AsyncTableResult).onClose(response);
        }
      };
      return response;
    } else if (rslt is Table) {
      response.updateStream(rslt.rows,
          columns: rslt.columns, streamStatus: StreamStatus.closed);
    } else if (rslt is Stream) {
      var r = new AsyncTableResult();
      Stream stream = rslt;
      if (rtype == "stream") {
        stream.listen((v) {
          if (v is Iterable) {
            r.update(v.toList());
          } else if (v is Map) {
            r.update([v]);
          } else {
            throw new Exception("Unknown Value from Stream");
          }
        }, onDone: () {
          r.close();
        }, onError: (e, stack) {
          var error = new DSError("invokeException", msg: e.toString());
          try {
            error.detail = stack.toString();
          } catch (e) {}
          response.close(error);
        }, cancelOnError: true);
        r.write(response);
        return response;
      } else {
        var list = [];
        stream.listen((v) {
          if (v is Iterable) {
            list.addAll(v);
          } else if (v is Map) {
            list.add(v);
          } else {
            throw new Exception("Unknown Value from Stream");
          }
        }, onDone: () {
          r.update(list);
          r.close();
        }, onError: (e, stack) {
          var error = new DSError("invokeException", msg: e.toString());
          try {
            error.detail = stack.toString();
          } catch (e) {}
          response.close(error);
        }, cancelOnError: true);
      }
      r.write(response);
      return response;
    } else if (rslt is Future) {
      var r = new AsyncTableResult();
      rslt.then((value) {
        r.update(value is Iterable ? value.toList() : [value]);
        r.close();
      }).catchError((e, stack) {
        var error = new DSError("invokeException", msg: e.toString());
        try {
          error.detail = stack.toString();
        } catch (e) {}
        response.close(error);
      });
      r.write(response);
      return response;
    } else {
      response.close();
    }

    return response;
  }

  /// This is called when this node is invoked.
  dynamic onInvoke(Map params) {
    return null;
  }

  void onSetValue(Object val) {}
  void onSetConfig(String name, String value){}
  void onSetAttribute(String name, String value){}

  // called before a subscription request is returned
  void onSubscribe() {}

  /// after node is created
  void onCreated() {}

  /// before node gets removed
  void onRemoving() {}

  /// after child node is removed
  void onChildRemoved(String name, Node node) {}

  /// after child node is created
  void onChildAdded(String name, Node node) {}

  @override
  RespSubscribeListener subscribe(callback(ValueUpdate), [int cacheLevel = 1]) {
    onSubscribe();
    return super.subscribe(callback, cacheLevel);
  }

  /// override default node creation logic for children
  SimpleNode onLoadChild(String name, Map data, SimpleNodeProvider provider) {
    return null;
  }

  SimpleNode createChild(String name, [Map m]) {
    var child = new SimpleNode("${path}/${name}", provider);
    if (m != null) {
      child.load(m);
    }
    addChild(name, child);
    return child;
  }

  void addChild(String name, Node node) {
    super.addChild(name, node);
    updateList(name);
  }

  String removeChild(dynamic input) {
    String name = super.removeChild(input);
    if (name != null) {
      updateList(name);
    }
    return name;
  }

  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    Response resp = super.setAttribute(name, value, responder, response);
    onSetAttribute(name, value);
    return resp;
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    Response resp = super.setConfig(name, value, responder, response);
    onSetConfig(name, value);
    return resp;
  }

  Response setValue(Object value, Responder responder, Response response,
      [int maxPermission = Permission.CONFIG]) {
    Response resp = super.setValue(value, responder, response, maxPermission);
    onSetValue(value);
    return resp;
  }


  operator []=(String name, value) {
    if (name.startsWith(r"$") || name.startsWith(r"@")) {
      if (name.startsWith(r"$")) {
        configs[name] = value;
      } else {
        attributes[name] = value;
      }
    } else {
      if (value == null) {
        return removeChild(name);
      } else if (value is Map) {
        return createChild(name, value);
      } else {
        addChild(name, value);
        return value;
      }
    }
  }
}

class SimpleHiddenNode extends SimpleNode {
  SimpleHiddenNode(String path, SimpleNodeProvider provider) : super(path, provider) {
    configs[r'$hide'] = true;
  }
  
  Map getSimpleMap() {
    Map rslt = {r'$hide':true};
    if (configs.containsKey(r'$is')) {
      rslt[r'$is'] = configs[r'$is'];
    }
    if (configs.containsKey(r'$type')) {
      rslt[r'$type'] = configs[r'$type'];
    }
    if (configs.containsKey(r'$name')) {
      rslt[r'$name'] = configs[r'$name'];
    }
    if (configs.containsKey(r'$invokable')) {
      rslt[r'$invokable'] = configs[r'$invokable'];
    }
    if (configs.containsKey(r'$writable')) {
      rslt[r'$writable'] = configs[r'$writable'];
    }
    // TODO add permission of current requester
    return rslt;
  }
}

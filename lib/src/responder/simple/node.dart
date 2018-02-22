part of dslink.responder;

typedef LocalNode NodeFactory(String path);
typedef SimpleNode SimpleNodeFactory(String path);
typedef Future<ByteData> IconResolver(String name);

/// Marks a node as being asynchronous when
/// accessed by the internals of a responder.
abstract class WaitForMe {
  Future get onLoaded;
}

/// A Simple Node Implementation.
/// A flexible node implementation that should fit most use cases.
class SimpleNode extends LocalNodeImpl {
  final SimpleNodeProvider provider;

  static  AESFastEngine _encryptEngine;
  static  KeyParameter _encryptParams;
  static initEncryption(String key) {
    _encryptEngine = new AESFastEngine();
    _encryptParams = new KeyParameter(UTF8.encode(key).sublist(48,80));
  }
  
  /// encrypt the string and prefix the value with '\u001Bpw:'
  /// so it's compatible with old plain text password
  static String encryptString(String str) {
    if (str == '') {
      return '';
    }
    _encryptEngine.reset();
    _encryptEngine.init(true, _encryptParams);

    Uint8List utf8bytes = UTF8.encode(str);
    Uint8List block = new Uint8List((utf8bytes.length + 31 )~/32 * 32);
    block.setRange(0, utf8bytes.length, utf8bytes);
    return '\u001Bpw:${Base64.encode(_encryptEngine.process(block))}';
  }

  static String decryptString(String str) {
    if (str.startsWith('\u001Bpw:')) {
      _encryptEngine.reset();
      _encryptEngine.init(false, _encryptParams);
      String rslt = UTF8.decode(_encryptEngine.process(Base64.decode(str.substring(4))));
      int pos = rslt.indexOf('\u0000');
      if (pos >= 0) rslt = rslt.substring(0, pos);
      return rslt;
    } else if (str.length == 22) {
      // a workaround for the broken password database, need to be removed later
      // 22 is the length of a AES block after base64 encoding
      // encoded password should always be 24 or more bytes, and a plain 22 bytes password is rare
      try{
        _encryptEngine.reset();
         _encryptEngine.init(false, _encryptParams);
         String rslt = UTF8.decode(_encryptEngine.process(Base64.decode(str)));
         int pos = rslt.indexOf('\u0000');
         if (pos >= 0) rslt = rslt.substring(0, pos);
         return rslt;
      } catch(err) {
        return str;
      }
    } else {
      return str;
    }
  }
  
  bool _stub = false;

  /// Is this node a stub node?
  /// Stub nodes are nodes which are stored in the tree, but are not actually
  /// part of their parent.
  bool get isStubNode => _stub;

  SimpleNode(String path, [SimpleNodeProvider nodeprovider]) :
    provider = nodeprovider == null ? SimpleNodeProvider.instance : nodeprovider,
      super(path);

  /// Marks a node as being removed.
  bool removed = false;

  /// Marks this node as being serializable.
  /// If true, this node can be serialized into a JSON file and then loaded back.
  /// If false, this node can't be serialized into a JSON file.
  bool serializable = true;

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
        if (_encryptEngine != null && key.startsWith(r'$$') && value is String) {
          configs[key] = decryptString(value);
        } else {
          configs[key] = value;
        }
       
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        String childPath = '$childPathPre$key';
        provider.addNode(childPath, value);
      }
    });
    _loaded = true;
  }

  /// Save this node into a map.
  Map save() {
    Map rslt = {};
    configs.forEach((str, val) {
      if (_encryptEngine != null && val is String && str.startsWith(r'$$') && str.endsWith('password')) {
        rslt[str] = encryptString(val);
      } else {
        rslt[str] = val;
      }
    });

    attributes.forEach((str, val) {
      rslt[str] = val;
    });

    if (_lastValueUpdate != null && _lastValueUpdate.value != null) {
      rslt['?value'] = _lastValueUpdate.value;
    }

    children.forEach((str, Node node) {
      if (node is SimpleNode && node.serializable == true) {
        rslt[str] = node.save();
      }
    });

    return rslt;
  }

  /// Handles the invoke method from the internals of the responder.
  /// Use [onInvoke] to handle when a node is invoked.
  InvokeResponse invoke(
    Map<String, dynamic> params,
    Responder responder,
    InvokeResponse response,
    Node parentNode,
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
      return response;
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
        rslt = [];
      } else if (rtype == "stream") {
        rslt = [];
      }
    }

    if (rslt is Iterable) {
      response.updateStream(rslt.toList(), streamStatus: StreamStatus.closed);
    } else if (rslt is Map) {
      var columns = [];
      var out = [];
      for (var x in rslt.keys) {
        columns.add({
          "name": x,
          "type": "dynamic"
        });
        out.add(rslt[x]);
      }

      response.updateStream(
        [out],
        columns: columns,
        streamStatus: StreamStatus.closed
      );
    } else if (rslt is SimpleTableResult) {
      response.updateStream(rslt.rows,
          columns: rslt.columns, streamStatus: StreamStatus.closed);
    } else if (rslt is AsyncTableResult) {
      (rslt as AsyncTableResult).write(response);
      response.onClose = (var response) {
        if ((rslt as AsyncTableResult).onClose != null) {
          (rslt as AsyncTableResult).onClose(response);
        }
      };
      return response;
    } else if (rslt is Table) {
      response.updateStream(rslt.rows,
          columns: rslt.columns, streamStatus: StreamStatus.closed);
    } else if (rslt is Stream) {
      var r = new AsyncTableResult();

      response.onClose = (var response) {
        if (r.onClose != null) {
          r.onClose(response);
        }
      };

      Stream stream = rslt;

      if (rtype == "stream") {
        StreamSubscription sub;

        r.onClose = (_) {
          if (sub != null) {
            sub.cancel();
          }
        };

        sub = stream.listen((v) {
          if (v is TableMetadata) {
            r.meta = v.meta;
            return;
          } else if (v is TableColumns) {
            r.columns = v.columns.map((x) => x.getData()).toList();
            return;
          }

          if (v is Iterable) {
            r.update(v.toList(), StreamStatus.open);
          } else if (v is Map) {
            var meta;
            if (v.containsKey("__META__")) {
              meta = v["__META__"];
            }
            r.update([v], StreamStatus.open, meta);
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
        StreamSubscription sub;

        r.onClose = (_) {
          if (sub != null) {
            sub.cancel();
          }
        };

        sub = stream.listen((v) {
          if (v is TableMetadata) {
            r.meta = v.meta;
            return;
          } else if (v is TableColumns) {
            r.columns = v.columns.map((x) => x.getData()).toList();
            return;
          }

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

      response.onClose = (var response) {
        if (r.onClose != null) {
          r.onClose(response);
        }
      };

      rslt.then((value) {
        if (value is LiveTable) {
          r = null;
          value.sendTo(response);
        } else if (value is Stream) {
          Stream stream = value;
          StreamSubscription sub;

          r.onClose = (_) {
            if (sub != null) {
              sub.cancel();
            }
          };

          sub = stream.listen((v) {
            if (v is TableMetadata) {
              r.meta = v.meta;
              return;
            } else if (v is TableColumns) {
              r.columns = v.columns.map((x) => x.getData()).toList();
              return;
            }

            if (v is Iterable) {
              r.update(v.toList());
            } else if (v is Map) {
              var meta;
              if (v.containsKey("__META__")) {
                meta = v["__META__"];
              }
              r.update([v], StreamStatus.open, meta);
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
        } else if (value is Table) {
          Table table = value;
          r.columns = table.columns.map((x) => x.getData()).toList();
          r.update(table.rows, StreamStatus.closed, table.meta);
          r.close();
        } else {
          r.update(value is Iterable ? value.toList() : [value]);
          r.close();
        }
      }).catchError((e, stack) {
        var error = new DSError("invokeException", msg: e.toString());
        try {
          error.detail = stack.toString();
        } catch (e) {}
        response.close(error);
      });
      r.write(response);
      return response;
    } else if (rslt is LiveTable) {
      rslt.sendTo(response);
    } else {
      response.close();
    }

    return response;
  }

  /// This is called when this node is invoked.
  /// You can return the following types from this method:
  /// - [Iterable]
  /// - [Map]
  /// - [Table]
  /// - [Stream]
  /// - [SimpleTableResult]
  /// - [AsyncTableResult]
  ///
  /// You can also return a future that resolves to one (like if the method is async) of the following types:
  /// - [Stream]
  /// - [Iterable]
  /// - [Map]
  /// - [Table]
  dynamic onInvoke(Map<String, dynamic> params) {
    return null;
  }

  /// Gets the parent node of this node.
  SimpleNode get parent => provider.getNode(new Path(path).parentPath);

  /// Callback used to accept or reject a value when it is set.
  /// Return true to reject the value, and false to accept it.
  bool onSetValue(Object val) => false;

  /// Callback used to accept or reject a value of a config when it is set.
  /// Return true to reject the value, and false to accept it.
  bool onSetConfig(String name, String value) => false;

  /// Callback used to accept or reject a value of an attribute when it is set.
  /// Return true to reject the value, and false to accept it.
  bool onSetAttribute(String name, String value) => false;

  // Callback used to notify a node that it is being subscribed to.
  void onSubscribe() {}

  // Callback used to notify a node that a subscribe has unsubscribed.
  void onUnsubscribe() {}

  /// Callback used to notify a node that it was created.
  /// This is called after a node is deserialized as well.
  void onCreated() {}

  /// Callback used to notify a node that it is about to be removed.
  void onRemoving() {}

  /// Callback used to notify a node that one of it's children has been removed.
  void onChildRemoved(String name, Node node) {}

  /// Callback used to notify a node that a child has been added to it.
  void onChildAdded(String name, Node node) {}

  @override
  RespSubscribeListener subscribe(ValueUpdateCallback callback, [int qos = 0]) {
    onSubscribe();
    return super.subscribe(callback, qos);
  }

  @override
  void unsubscribe(ValueUpdateCallback callback) {
    onUnsubscribe();
    super.unsubscribe(callback);
  }

  /// Callback to override how a child of this node is loaded.
  /// If this method returns null, the default strategy is used.
  SimpleNode onLoadChild(String name, Map data, SimpleNodeProvider provider) {
    return null;
  }

  /// Creates a child with the given [name].
  /// If [m] is specified, the node is loaded with that map.
  SimpleNode createChild(String name, [Map m]) {
    var tp = new Path(path).child(name).path;
    return provider.addNode(tp, m == null ? {} : m);
  }

  /// Gets the name of this node.
  /// This is the last component of this node's path.
  String get name => new Path(path).name;

  /// Gets the current display name of this node.
  /// This is the $name config. If it does not exist, then null is returned.
  String get displayName => configs[r"$name"];

  /// Sets the display name of this node.
  /// This is the $name config. If this is set to null, then the display name is removed.
  set displayName(String value) {
    if (value == null) {
      configs.remove(r"$name");
    } else {
      configs[r"$name"] = value;
    }

    updateList(r"$name");
  }

  /// Gets the current value type of this node.
  /// This is the $type config. If it does not exist, then null is returned.
  String get type => configs[r"$type"];

  /// Sets the value type of this node.
  /// This is the $type config. If this is set to null, then the value type is removed.
  set type(String value) {
    if (value == null) {
      configs.remove(r"$type");
    } else {
      configs[r"$type"] = value;
    }

    updateList(r"$type");
  }

  /// Gets the current value of the $writable config.
  /// If it does not exist, then null is returned.
  String get writable => configs[r"$writable"];

  /// Sets the value of the writable config.
  /// If this is set to null, then the writable config is removed.
  set writable(value) {
    if (value == null) {
      configs.remove(r"$writable");
    } else if (value is bool) {
      if (value) {
        configs[r"$writable"] = "write";
      } else {
        configs.remove(r"$writable");
      }
    } else {
      configs[r"$writable"] = value.toString();
    }

    updateList(r"$writable");
  }

  /// Checks if this node has the specified config.
  bool hasConfig(String name) => configs.containsKey(
      name.startsWith(r"$") ? name : '\$' + name
  );

  /// Checks if this node has the specified attribute.
  bool hasAttribute(String name) => attributes.containsKey(
      name.startsWith("@") ? name : '@' + name
  );

  /// Remove this node from it's parent.
  void remove() {
    provider.removeNode(path);
  }

  /// Add this node to the given node.
  /// If [input] is a String, it is interpreted as a node path and resolved to a node.
  /// If [input] is a [SimpleNode], it will be attached to that.
  void attach(input, {String name}) {
    if (name == null) {
      name = this.name;
    }

    if (input is String) {
      provider.getNode(input).addChild(name, this);
    } else if (input is SimpleNode) {
      input.addChild(name, this);
    } else {
      throw "Invalid Input";
    }
  }

  /// Adds the given [node] as a child of this node with the given [name].
  void addChild(String name, Node node) {
    super.addChild(name, node);
    updateList(name);
  }

  /// Removes a child from this node.
  /// If [input] is a String, a child named with the specified [input] is removed.
  /// If [input] is a Node, the child that owns that node is removed.
  /// The name of the removed node is returned.
  String removeChild(dynamic input) {
    String name = super.removeChild(input);
    if (name != null) {
      updateList(name);
    }
    return name;
  }

  Response setAttribute(
      String name, Object value, Responder responder, Response response) {
    if (onSetAttribute(name, value) != true) {
      // when callback returns true, value is rejected
      super.setAttribute(name, value, responder, response);
    }
    return response;
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    if (onSetConfig(name, value) != true) {
      // when callback returns true, value is rejected
      super.setConfig(name, value, responder, response);
    }
    return response;
  }

  Response setValue(Object value, Responder responder, Response response,
      [int maxPermission = Permission.CONFIG]) {
    if (onSetValue(value) !=  true)
      // when callback returns true, value is rejected
      super.setValue(value, responder, response, maxPermission);
    return response;
  }

  operator [](String name) => get(name);

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

/// A hidden node.
class SimpleHiddenNode extends SimpleNode {
  SimpleHiddenNode(String path, SimpleNodeProvider provider) : super(path, provider) {
    configs[r'$hidden'] = true;
  }

  @override
  Map<String, dynamic> getSimpleMap() {
    var rslt = <String, dynamic>{
      r'$hidden': true
    };

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
    return rslt;
  }
}

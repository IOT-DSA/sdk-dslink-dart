part of dslink.broker;

class RemoteLinkManager implements NodeProvider, RemoteNodeCache {
  final Map<String, RemoteLinkNode> nodes = new Map<String, RemoteLinkNode>();
  Requester requester;
  final String path;
  final BrokerNodeProvider broker;
  RemoteLinkRootNode rootNode;
  
  String disconnected = ValueUpdate.getTs();
  
  RemoteLinkManager(this.broker, this.path, NodeProviderImpl brokerProvider, [Map rootNodeData]) {
    requester = new RemoteRequester(this);
    rootNode = new RemoteLinkRootNode(path, '/', this);
    nodes['/'] = rootNode;
    if (rootNodeData != null) {
      rootNode.load(rootNodeData, brokerProvider);
    }
  }

  Map<String, Responder> responders;
  /// multiple-requester is allowed, like from different browser tabs
  /// in this case they need multiple responders on broker side.
  Responder getResponder(NodeProvider nodeProvider, [String sessionId = '']) {
    if (responders == null) {
      responders = {};
    }
    if (responders.containsKey(sessionId)) {
      return responders[sessionId];
    } else {
      var responder = new Responder(nodeProvider);
      responder.reqId = path.substring(7); // remove /conns/
      //TODO set permission group
      responders[sessionId] = responder;
      return responder;
    }
  }

  LocalNode getNode(String fullPath) {
    String rPath = fullPath.replaceFirst(path, '');
    if (rPath == '') {
      rPath = '/';
    }
    RemoteLinkNode node = nodes[rPath];
    if (node == null) {
      node = new RemoteLinkNode(fullPath, rPath, this);
      nodes[rPath] = node;
    }
    return node;
  }

  RemoteNode getRemoteNode(String rPath) {
    String fullPath = path + rPath;
    if (rPath == '') {
      rPath = '/';
    }
    RemoteLinkNode node = nodes[rPath];
    if (node == null) {
      node = new RemoteLinkNode(fullPath, rPath, this);
      nodes[rPath] = node;
    }
    return node;
  }
  Node getDefNode(String rPath) {
    // reuse local broker node and doesn't reload it
    if (rPath.startsWith('/defs/') && broker.nodes.containsKey(rPath)) {
      LocalNode node = broker.nodes[rPath];
      if (node is LocalNodeImpl && node.loaded) {
        return node;
      }
    }
    return getRemoteNode(rPath);
  }
  RemoteNode updateRemoteChildNode(RemoteNode parent, String name, Map m) {
    String path;
    if (parent.remotePath == '/') {
      path = '/$name';
    } else {
      path = '${parent.remotePath}/$name';
    }
    if (parent is RemoteLinkNode) {
      RemoteLinkNode node = parent._linkManager.getRemoteNode(path);
      node.updateRemoteChildData(m, this);
      return node;
    }
    return null;
  }

  PermissionList permissions;
  // TODO, implement this in rootNode and use its configs and parent node
  int getPermission(Responder responder) {
    PermissionList ps = permissions;
    if (ps != null) {
      ps.getPermission(responder);
    }
    return Permission.NONE;
  }
}
class RemoteLinkNode extends RemoteNode implements LocalNode {
  PermissionList get permissions => null;
  int getPermission(Responder responder) {
    return _linkManager.getPermission(responder);
  }

  BroadcastStreamController<String> _listChangeController;
  BroadcastStreamController<String> get listChangeController {
    if (_listChangeController == null) {
      _listChangeController = new BroadcastStreamController<String>(
          _onStartListListen, _onAllListCancel);
    }
    return _listChangeController;
  }
  Stream<String> get listStream => listChangeController.stream;
  StreamSubscription _listReqListener;

  void _onStartListListen() {
    if (_listReqListener == null) {
      _listReqListener =
          _linkManager.requester.list(remotePath).listen(_onListUpdate);
    }
  }

  void _onAllListCancel() {
    if (_listReqListener != null) {
      _listReqListener.cancel();
      _listReqListener = null;
    }
    _listReady = false;
  }

  void _onListUpdate(RequesterListUpdate update) {
    for (var change in update.changes) {
      listChangeController.add(change);
    }
    _listReady = true;
  }

  Map<Function, int> callbacks = new Map<Function, int>();
  RespSubscribeListener subscribe(callback(ValueUpdate), [int cachelevel = 1]) {
    callbacks[callback] = cachelevel;
    var rslt = new RespSubscribeListener(this, callback);
    _linkManager.requester.subscribe(remotePath, updateValue, cachelevel);
    return rslt;
  }
  void unsubscribe(callback(ValueUpdate)) {
    if (callbacks.containsKey(callback)) {
      callbacks.remove(callback);
    }
    if (callbacks.isEmpty) {
      _linkManager.requester.unsubscribe(remotePath, updateValue);
      _valueReady = false;
    }
  }

  ValueUpdate _lastValueUpdate;
  ValueUpdate get lastValueUpdate {
    return _lastValueUpdate;
  }

  void updateValue(Object update) {
    if (update is ValueUpdate) {
      _lastValueUpdate = update;
      callbacks.forEach((callback, cachelevel) {
        callback(_lastValueUpdate);
      });
    } else if (_lastValueUpdate == null || _lastValueUpdate.value != update) {
      _lastValueUpdate = new ValueUpdate(update);
      callbacks.forEach((callback, cachelevel) {
        callback(_lastValueUpdate);
      });
    }
  }

  final String path;
  /// root of the link
  RemoteLinkManager _linkManager;

  RemoteLinkNode(this.path, String remotePath, this._linkManager)
      : super(remotePath) {}

  bool _listReady = false;
  /// whether broker is already listing, can send data directly for new list request
  bool get listReady => _listReady;
  String get disconnected => _linkManager.disconnected;
  
  bool _valueReady = false;
  /// whether broker is already subscribing, can send value directly for new subscribe request
  bool get valueReady => _valueReady;

  bool get exists => true;

  InvokeResponse invoke(
      Map params, Responder responder, InvokeResponse response) {
    // TODO, when invoke closed without any data, also need to updateStream to close
    StreamSubscription sub = _linkManager.requester
        .invoke(remotePath, params)
        .listen((RequesterInvokeUpdate update) {
      // TODO fix paths in the response
      response.updateStream(update.updates,
          streamStatus: update.streamStatus, columns: update.rawColumns);
    }, onDone: () {
      response.close();
    });
    response.onClose = (InvokeResponse rsp) {
      sub.cancel();
    };
    return response;
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    _linkManager.requester.remove(remotePath).then((update) {
      response.close();
    }).catchError((err) {
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail: '$err'));
      }
    });
    return response;
  }

  Response removeConfig(String name, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    _linkManager.requester.remove(remotePath).then((update) {
      response.close();
    }).catchError((err) {
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail: '$err'));
      }
    });
    return response;
  }

  Response setAttribute(
      String name, String value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    _linkManager.requester.set('$remotePath/$name', value).then((update) {
      response.close();
    }).catchError((err) {
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail: '$err'));
      }
    });
    return response;
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    _linkManager.requester.set('$remotePath/$name', value).then((update) {
      response.close();
    }).catchError((err) {
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail: '$err'));
      }
    });
    return response;
  }

  Response setValue(Object value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    _linkManager.requester.set(remotePath, value).then((update) {
      response.close();
    }).catchError((err) {
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail: '$err'));
      }
    });
    return response;
  }

  Map _lastChildData;
  void updateRemoteChildData(Map m, RemoteNodeCache cache) {
    _lastChildData = m;
    super.updateRemoteChildData(m, cache);
  }
  /// get simple map should return all configs returned by remoteNode
  Map getSimpleMap() {
    Map m = super.getSimpleMap();
    if (_lastChildData != null) {
      _lastChildData.forEach((String key, value) {
        if (key.startsWith(r'$')) {
          m[key] = this.configs[key];
        }
      });
    }
    return m;
  }

}


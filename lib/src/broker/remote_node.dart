part of dslink.broker;

class RemoteLinkManager implements NodeProvider, RemoteNodeCache {
  final Map<String, RemoteLinkNode> nodes = new Map<String, RemoteLinkNode>();
  Requester requester;
  final String path;
  RemoteLinkRootNode rootNode;
  RemoteLinkManager(this.path) {
    requester = new Requester(this);
    rootNode = new RemoteLinkRootNode(path, '/', requester, this);
    nodes['/'] = rootNode;
  }

  LocalNode getNode(String fullPath) {
    String rPath = fullPath.replaceFirst(path, '');
    if (rPath == '') {
      rPath = '/';
    }
    RemoteLinkNode node = nodes[rPath];
    if (node == null) {
      node = new RemoteLinkNode(fullPath, rPath, requester, this);
      nodes[rPath] = node;
    }
    return node;
  }

  RemoteNode getRemoteNode(String rPath, Requester requester) {
    String fullPath = path + rPath;
    if (rPath == '') {
      rPath = '/';
    }
    RemoteLinkNode node = nodes[rPath];
    if (node == null) {
      node = new RemoteLinkNode(fullPath, rPath, requester, this);
      nodes[rPath] = node;
    }
    return node;
  }

  RemoteNode updateRemoteNode(Map m) {
    // TODO: implement updateRemoteNode
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
      _listChangeController = new BroadcastStreamController<String>(_onStartListListen, _onAllListCancel);
    }
    return _listChangeController;
  }
  Stream<String> get listStream => listChangeController.stream;
  StreamSubscription _listReqListener;

  void _onStartListListen() {
    if (_listReqListener == null) {
      _listReqListener = requester.list(remotePath).listen(_onListUpdate);
    }
  }

  void _onAllListCancel() {
    if (_listReqListener != null) {
      _listReqListener.cancel();
      _listReqListener = null;
    }
  }

  void _onListUpdate(RequesterListUpdate update) {
    for (var change in update.changes) {
      listChangeController.add(change);
    }
  }

  BroadcastStreamController<ValueUpdate> _valueController;
  BroadcastStreamController<ValueUpdate> get valueController {
    if (_valueController == null) {
      _valueController = new BroadcastStreamController<ValueUpdate>(_onStartValueListen, _onAllValueCancel);
    }
    return _valueController;
  }

  Stream<ValueUpdate> get valueStream => valueController.stream;
  StreamSubscription _valueReqListener;

  void _onStartValueListen() {
    print('value listener added');
    if (_valueReqListener == null) {
      _valueReqListener = requester.subscribe(remotePath).listen(_onValueUpdate);
    }
  }

  void _onAllValueCancel() {
    if (_valueReqListener != null) {
      _valueReqListener.cancel();
      _valueReqListener = null;
    }
  }

  void _onValueUpdate(ValueUpdate update) {
    _valueController.add(update);
  }

  final String path;
  /// root of the link
  RemoteLinkManager _linkManager;

  RemoteLinkNode(this.path, String remotePath, Requester requester, this._linkManager)
      : super(remotePath, requester) {}

  bool _listReady = false;
  bool get listReady => _listReady;

  bool get exists => true;

  @override
  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    requester.invoke(remotePath, params).listen((update) {
      // TODO fix paths in the response
      response.updateStream(update.updates, streamStatus: update.streamStatus, columns: update.columns);
    });
    return response;
  }

  Response removeAttribute(String name, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    requester.remove(remotePath).then((update){
      response.close();
    }).catchError((err){
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail:'$err'));
      }
    });
    return response;
  }

  Response removeConfig(String name, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    requester.remove(remotePath).then((update){
      response.close();
    }).catchError((err){
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail:'$err'));
      }
    });
    return response;
  }

  Response setAttribute(String name, String value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    requester.set(remotePath, value).then((update){
      response.close();
    }).catchError((err){
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail:'$err'));
      }
    });
    return response;
  }

  Response setConfig(String name, Object value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    requester.set(remotePath, value).then((update){
      response.close();
    }).catchError((err){
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail:'$err'));
      }
    });
    return response;
  }

  Response setValue(Object value, Responder responder, Response response) {
    // TODO check permission on RemoteLinkRootNode
    requester.set(remotePath, value).then((update){
      response.close();
    }).catchError((err){
      if (err is DSError) {
        response.close(err);
      } else {
        // TODO need a broker setting to disable detail
        response.close(new DSError('internalError', detail:'$err'));
      }
    });
    return response;
  }

  ListResponse list(Responder responder, ListResponse response) {
    // this is automaticaly implemented
    // no need to do anything else here
    return response;
  }

  RespSubscribeController subscribe(SubscribeResponse subscription, Responder responder) {
    return new RespSubscribeController(subscription, this);
  }
}

// TODO, implement special configs and attribute merging
class RemoteLinkRootNode extends RemoteLinkNode {
  RemoteLinkRootNode(String path, String remotePath, Requester requester, RemoteLinkManager linkManager) : super(path, remotePath, requester, linkManager);
  
}
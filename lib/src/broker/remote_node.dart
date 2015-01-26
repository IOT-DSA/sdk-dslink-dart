part of dslink.broker;

class RemoteLinkManager implements NodeProvider, RemoteNodeCache {
  final Map<String, RemoteLinkNode> nodes = new Map<String, RemoteLinkNode>();
  Requester requester;
  final String path;
  RemoteLinkManager(this.path) {
    requester = new Requester(this);
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
  }
}
class RemoteLinkNode extends RemoteNode implements LocalNode {
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
      _valueController = new BroadcastStreamController<ValueUpdate>(
          _onStartValueListen, _onAllValueCancel);
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
  RemoteLinkManager _linkNode;
  RemoteLinkNode(this.path, String remotePath, Requester requester, this._linkNode)
      : super(remotePath, requester) {}

  bool _listReady = false;
  bool get listReady => _listReady;

  bool get exists => true;

  @override
  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    requester.invoke(remotePath, params).listen((update) {
      // TODO fix paths in the response
      response.updateStream(update.updates,
          streamStatus: update.streamStatus, columns: update.columns);
    });
    return response;
  }

  @override
  Response removeAttribute(String name, Responder responder, Response rid) {
    // TODO: implement removeAttribute
  }

  @override
  Response removeConfig(String name, Responder responder, Response rid) {
    // TODO: implement removeConfig
  }

  @override
  Response setAttribute(String name, String value, Responder responder, Response rid) {
    // TODO: implement setAttribute
  }

  @override
  Response setConfig(String name, Object value, Responder responder, Response rid) {
    // TODO: implement setConfig
  }

  @override
  Response setValue(Object value, Responder responder, Response rid) {
    // TODO: implement setValue
  }

  ListResponse list(Responder responder, ListResponse response) {
    return response;
  }
  RespSubscribeController subscribe(SubscribeResponse subscription, Responder responder) {
    return new RespSubscribeController(subscription, this);
  }
}

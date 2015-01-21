part of dslink.broker;

class BrokerNodeProvider extends NodeProvider implements ServerLinkManager {
  final Map<String, ResponderNode> nodes = new Map<String, ResponderNode>();
  final Map<String, RemoteLinkRoot> conns = new Map<String, RemoteLinkRoot>();
  ResponderNode getNode(String path) {
    ResponderNode node = nodes[path];
    if (node != null) {
      return node;
    }
    if (path.startsWith('/conns/')) {
      int slashPos = path.indexOf('/', 7);
      String connName;
      if (slashPos < 0) {
        connName = path.substring(7);
      } else {
        connName = path.substring(7, slashPos);
      }
      RemoteLinkRoot conn = conns[connName];
      if (conn == null) {
        conn = new RemoteLinkRoot('/conns/$connName');
        conns[connName] = conn;
      }
      node = conn.getNode(path);
    } else {
      // TODO
    }
    return node;
  }

  /// server links
  final Map<String, ServerLink> _links = new Map<String, ServerLink>();

  final Map<ServerLink, String> _link2ConnName = new Map<ServerLink, String>();
  final Map<String, ServerLink> _connName2Link = new Map<String, ServerLink>();
  void addLink(ServerLink link) {
    String dsId = link.dsId;
    String connName;
    // TODO update children list of /conns node
    if (_links.containsKey(dsId)) {
      connName = _link2ConnName[link];
      // TODO is it possible same link get added twice?
    } else {
      _links[dsId] = link;

      // find a connName for it
      for (int i = 63; i >= 0; --i) {
        connName = dsId.substring(0, dsId.length - i);
        if (!_connName2Link.containsKey(connName)) {
          _connName2Link[connName] = link;
          _link2ConnName[link] = connName;
          break;
        }
      }
      print('new node added at /conns/$connName');
    }
    (getNode('/conns/$connName') as RemoteLinkRoot).updateRequester(link.requester);
  }

  ServerLink getLink(String dsId) {
    return _links[dsId];
  }

  void removeLink(ServerLink link) {
    if (_links[link.dsId] == link) {
      _links.remove(link.dsId);
    }
  }
}
class RemoteLinkRoot extends RemoteNode implements NodeProvider {
  final Map<String, RemoteNode> nodes = new Map<String, RemoteNode>();
  Requester _requester;
  void updateRequester(Requester req) {
    super.updateRequester(req);
    nodes.forEach((k, node) {
      if (node != this) {
        node.updateRequester(req);
      }
    });
  }
  RemoteLinkRoot(String path) : super(path, null, '/') {
    _linkNode = this;
    nodes[''] = this;
    nodes['/'] = this;
  }

  ResponderNode getNode(String fullPath) {
    String remotePath = fullPath.replaceFirst(path, '');
    ResponderNode node = nodes[remotePath];
    if (node == null) {
      node = new RemoteNode(fullPath, this, remotePath);
      nodes[remotePath] = node;
    }
    return node;
  }
}
class RemoteNode extends Node implements ResponderNode {

  Requester _requester;
  void updateRequester(Requester req) {
    _requester = req;
    if (_valueListeners != null) {
      if (_valueReqListener != null) {
        _valueReqListener.cancel();
      }
      _valueReqListener = _requester.subscribe(remotePath).listen(_onValueUpdate);
    }
    // TODO listChangeReqListener
  }

  final StreamController<String> listChangeController = new StreamController<String>();
  Stream<String> _listStream;
  Stream<String> get listStream {
    if (_listStream == null) {
      _listStream = listChangeController.stream.asBroadcastStream();
    }
    return _listStream;
  }

  StreamController<ValueUpdate> _valueController;
  StreamController<ValueUpdate> get valueController {
    // lazy initialize
    if (_valueController == null) {
      _valueController = new StreamController<ValueUpdate>();
    }
    return _valueController;
  }
  Stream<ValueUpdate> _valueStream;
  Stream<ValueUpdate> get valueStream {
    if (_valueStream == null) {
      _valueListeners = new HashSet();
      _valueStream = valueController.stream.asBroadcastStream(onListen: _onValueListen, onCancel: _onValueCancel);
    }
    return _valueStream;
  }
  HashSet _valueListeners;
  StreamSubscription _valueReqListener;
  void _onValueListen(StreamSubscription<ValueUpdate> listener) {
    if (!_valueListeners.contains(listener)) {
      _valueListeners.add(listener);

      if (_valueReqListener == null && _linkNode._requester != null) {
        _valueReqListener = _linkNode._requester.subscribe(remotePath).listen(_onValueUpdate);
      }
    }
  }

  void _onValueCancel(StreamSubscription<ValueUpdate> listener) {
    if (_valueListeners.contains(listener)) {
      _valueListeners.remove(listener);
      if (_valueListeners.isEmpty) {
        if (_valueReqListener != null) {
          _valueReqListener.cancel();
          _valueReqListener = null;
        }
      }
    }
  }
  void _onValueUpdate(ValueUpdate update) {
    _valueController.add(update);
  }


  /// root of the link
  RemoteLinkRoot _linkNode;
  final String remotePath;
  RemoteNode(String path, this._linkNode, this.remotePath) : super(path) {
  }

  bool _listReady = false;
  bool get listReady => _listReady;

  bool get exists => true;

  @override
  InvokeResponse invoke(Map params, Responder responder, InvokeResponse response) {
    _requester.invoke(remotePath, params).listen((update) {
      // TODO fix paths in the response
      response.updateStream(update.updates, streamStatus: update.streamStatus, columns: update.columns);
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

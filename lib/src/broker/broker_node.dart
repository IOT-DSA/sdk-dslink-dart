part of dslink.broker;

class BrokerNodeProvider extends NodeProvider implements ServerLinkManager {
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();
  /// connName to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();
  LocalNode getNode(String path) {
    LocalNode node = nodes[path];
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
      RemoteLinkManager conn = conns[connName];
      if (conn == null) {
        conn = new RemoteLinkManager('/conns/$connName');
        conns[connName] = conn;
      }
      node = conn.getNode(path);
    } else {
      // TODO
    }
    return node;
  }

  /// dsId to server links
  final Map<String, ServerLink> _links = new Map<String, ServerLink>();

  final Map<String, String> _id2connName = new Map<String, String>();
  final Map<String, String> _connName2id = new Map<String, String>();
  String getConnName(String dsId) {
    if (_id2connName.containsKey(dsId)) {
      return _id2connName[dsId];
      // TODO is it possible same link get added twice?
    } else {
      String connName;
      // find a connName for it
      for (int i = 63; i >= 0; --i) {
        connName = dsId.substring(0, dsId.length - i);
        if (!_connName2id.containsKey(connName)) {
          _connName2id[connName] = dsId;
          _id2connName[dsId] = connName;
          break;
        }
      }
      return connName;
    }
  }
  void addLink(ServerLink link) {
    String dsId = link.dsId;
    String connName;
    // TODO update children list of /conns node
    if (_links.containsKey(dsId)) {
      // TODO is it possible same link get added twice?
    } else {
      _links[dsId] = link;

      connName = getConnName(dsId);
      print('new node added at /conns/$connName');
    }
  }

  ServerLink getLink(String dsId) {
    return _links[dsId];
  }

  void removeLink(ServerLink link) {
    if (_links[link.dsId] == link) {
      _links.remove(link.dsId);
    }
  }

  Requester getRequester(String dsId) {
    String connName = getConnName(dsId);
    if (conns.containsKey(connName)) {
      return conns[connName].requester;
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getNode('/conns/$connName');
    return node.requester;
  }

  Responder getResponder(String dsId, NodeProvider nodeProvider) {
    return new Responder(nodeProvider);
  }
}
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


  final StreamController<String> listChangeController = new StreamController<String>();
  Stream<String> _listStream;
  Stream<String> get listStream {
    if (_listStream == null) {
      _listStream = listChangeController.stream.asBroadcastStream(onListen: _onListListen, onCancel: _onListCancel);
    }
    return _listStream;
  }
  HashSet _listListeners;
  StreamSubscription _listReqListener;
  void _onListListen(StreamSubscription<String> listener) {
    if (!_listListeners.contains(listener)) {
      _listListeners.add(listener);

      if (_listReqListener == null && _linkNode.requester != null) {
        _listReqListener = _linkNode.requester.list(remotePath).listen(_onListUpdate);
      }
    }
  }

  void _onListCancel(StreamSubscription<String> listener) {
    if (_listListeners.contains(listener)) {
      _listListeners.remove(listener);
      if (_listListeners.isEmpty) {
        if (_listReqListener != null) {
          _listReqListener.cancel();
          _listReqListener = null;
        }
      }
    }
  }
  void _onListUpdate(RequesterListUpdate update) {
    for (var change in update.changes) {
      listChangeController.add(change);
    }
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

      if (_valueReqListener == null && _linkNode.requester != null) {
        _valueReqListener = _linkNode.requester.subscribe(remotePath).listen(_onValueUpdate);
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


  final String path;
  /// root of the link
  RemoteLinkManager _linkNode;
  RemoteLinkNode(this.path, String remotePath, Requester requester, this._linkNode) : super(remotePath, requester) {
  }

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

part of dslink.broker;

class BrokerNodeProvider extends SerializableNodeProvider implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connName to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();

  Map rootStructure = {
    'conns': {},
    'defs': {},
    'quarantine': {}
  };
  BrokerNodeProvider() {
    // initialize root nodes
    RootNode root = new RootNode('/');
    nodes['/'] = root;
    root.load(rootStructure, this);
  }

  bool _defsLoaded = false;
  /// load a fixed profile map
  void loadDefs(Map m) {
    _defsLoaded = false;
    (getNode('/defs') as SerializableNode).load(m, this);
    _defsLoaded = true;
    // TODO send requester an update about profile change
  }

  /// load a local node
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
    } else if (path.startsWith('/defs/')) {
      if (!_defsLoaded) {
        node = new DefinitionNode(path);
      }
      // can't create arbitrary profile at runtime
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
      for (int i = 42; i >= 0; --i) {
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

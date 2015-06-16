part of dslink.broker;

class BrokerNodeProvider extends NodeProviderImpl implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connName to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();

  
  
  IPermissionManager permissions;
    
  LocalNodeImpl connsNode;
  Map rootStructure = {'users':{}, 'conns': {}, 'defs': {}, 'quarantine': {}, 'sys': {}};

  BrokerNodeProvider() {
    permissions = new BrokerPermissions();
    // initialize root nodes
    RootNode root = new RootNode('/');
    nodes['/'] = root;
    root.load(rootStructure, this);
    connsNode = nodes['/conns'];
    initSys();
  }

  void initSys() {
    setNode("/sys/version", new BrokerVersionNode("/sys/version", DSA_VERSION));
    setNode("/sys/startTime", new StartTimeNode("/sys/startTime"));
    setNode("/sys/clearConns", new ClearConnsAction("/sys/clearConns", this));
    setNode("/sys/throughput", ThroughPutNode.instance);
  }

  bool _defsLoaded = false;

  /// load a fixed profile map
  void loadDefs(Map m) {
    _defsLoaded = false;
    (getNode('/defs') as LocalNodeImpl).load(m, this);
    _defsLoaded = true;
    // TODO send requester an update says: all profiles changed
  }

  Map _pendingDevices = {};

  void loadConns() {
    // loadConns from file
    File connsFile = new File("conns.json");
    try {
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/conns/$name';
        RemoteLinkRootNode node = getNode(path);
        node.load(m, this);
        if (node.configs[r'$$dsId'] is String) {
          _id2connPath[node.configs[r'$$dsId']] = path;
          _connPath2id[path] = node.configs[r'$$dsId'];
        }
      });
    } catch (err) {
    }
  }

  Map saveConns() {
    Map m = {};
    connsNode.children.forEach((String name, RemoteLinkNode node) {
      RemoteLinkManager manager = node._linkManager;
      m[name] = manager.rootNode.serialize(false);
    });
    File connsFile = new File("conns.json");
    connsFile.writeAsStringSync(DsJson.encode(m));
    return m;
  }

  // remove disconnected nodes from the conns node
  void clearConns() {
    List names = connsNode.children.keys.toList();
    for (String name in names) {
      RemoteLinkNode node = connsNode.children[name];
      RemoteLinkManager manager = node._linkManager;
      if (manager.disconnected != null) {
        connsNode.children.remove(name);
        manager.inTree = false;
        connsNode.updateList(name);
      }
    }
    DsTimer.timerOnceAfter(saveConns, 3000);
  }

  /// add a node to the tree
  void setNode(String path, LocalNode newNode) {
    LocalNode node = nodes[path];
    if (node != null) {
      logger.severe('error, BrokerNodeProvider.setNode same node can not be set twice');
      return;
    }

    Path p = new Path(path);
    LocalNode parentNode = nodes[p.parentPath];
    if (parentNode == null) {
      logger.severe('error, BrokerNodeProvider.setNode parentNode is null');
      return;
    }

    nodes[path] = newNode;
    parentNode.addChild(p.name, newNode);
  }

  /// load a local node
  LocalNode getNode(String path) {
    LocalNode node = nodes[path];

    if (node != null) {
      return node;
    }
    if (path.startsWith('/users/')) {
      String username = path.split('/')[2];
      int pos = path.indexOf('/#');
      if (pos > 0) {
        // link node
        
      } else {
        // user node
        
      }
      
    } else if (path.startsWith('/conns/')) {
      String connName = path.split('/')[2];
      String connPath = '/conns/$connName';
      RemoteLinkManager conn = conns[connPath];
      if (conn == null) {
        // TODO conn = new RemoteLinkManager('/conns/$connName', connRootNodeData);
        conn = new RemoteLinkManager(this, connPath, connName, this);
        conns[connPath] = conn;
        nodes[connPath] = conn.rootNode;
        connsNode.children[connName] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
        conn.inTree = true;
        connsNode.updateList(connName);
      }
      node = conn.getNode(path);
    } else if (path.startsWith('/defs/')) {
      if (!_defsLoaded) {
        node = new DefinitionNode(path);
      }
      // can't create arbitrary profile at runtime
    } else {
      node = new BrokerNode(path);
    }
    if (node != null) {
      nodes[path] = node;
    }
    return node;
  }

  /// dsId to server links
  final Map<String, ServerLink> _links = new Map<String, ServerLink>();
  final Map<String, String> _id2connPath = new Map<String, String>();
  final Map<String, String> _connPath2id = new Map<String, String>();

  String getConnPath(String dsId) {
    if (_id2connPath.containsKey(dsId)) {
      return _id2connPath[dsId];
      // TODO is it possible same link get added twice?
    } else if (dsId.length < 43) {
      // user link
      String connPath = '/conns/$dsId';
      int count = 0;
      // find a connName for it
      while (_connPath2id.containsKey(connPath)) {
        connPath = '/conns/$dsId-${count++}';
      }
      _connPath2id[connPath] = dsId;
      _id2connPath[dsId] = connPath;
      return connPath;
    } else {
      // device link
      String connPath;

      // find a connName for it, keep append characters until find a new name
      int i = 43;
      if (dsId.length == 43) i = 42;
      for (; i >= 0; --i) {
        connPath = '/conns/${dsId.substring(0, dsId.length - i)}';
        if (i == 43 && connPath.length > 8 && connPath.endsWith('-')) {
          // remove the last - in the name;
          connPath = connPath.substring(0, connPath.length - 1);
        }
        if (!_connPath2id.containsKey(connPath)) {
          _connPath2id[connPath] = dsId;
          _id2connPath[dsId] = connPath;
          break;
        }
      }
      DsTimer.timerOnceAfter(saveConns, 3000);
      return connPath;
    }
  }

  void addLink(ServerLink link) {
    String str = link.dsId;
    if (link.session != null) {
      str = '$str ${link.session}';
    }

    String connPath;
    // TODO update children list of /conns node
    if (_links.containsKey(str)) {
      // TODO is it possible same link get added twice?
    } else {
      _links[str] = link;
      if (link.session == null) {
        // don't create node for requester node with session
        connPath = getConnPath(str);
        getNode(connPath).configs[r'$$dsId'] = link.dsId;
        logger.info('new node added at $connPath');
      }
    }
  }

  ServerLink getLink(String dsId, {String sessionId:''}) {
    String str = dsId;
    if (sessionId != null && sessionId != '') {
      str = '$dsId sessionId';
    }
    if (_links[str] != null) {
      String connPath = getConnPath(str);
      RemoteLinkNode node = getNode(connPath);
      RemoteLinkManager conn = node._linkManager;
      if (!conn.inTree) {
        connsNode.children[conn.name] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
        conn.inTree = true;
        connsNode.updateList(conn.name);
      }
    }
    return _links[str];
  }

  void removeLink(ServerLink link) {
    if (_links[link.dsId] == link) {
      _links.remove(link.dsId);
    }
  }

  Requester getRequester(String dsId) {
    String connPath = getConnPath(dsId);
    if (conns.containsKey(getConnPath)) {
      return conns[connPath].requester;
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getNode(connPath);
    return node._linkManager.requester;
  }

  Responder getResponder(String dsId, NodeProvider nodeProvider,
                         [String sessionId = '']) {
    String connPath = getConnPath(dsId);
    if (conns.containsKey(connPath)) {
      return conns[connPath].getResponder(nodeProvider, sessionId);
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getNode(connPath);
    return node._linkManager.getResponder(nodeProvider, sessionId);
  }
}

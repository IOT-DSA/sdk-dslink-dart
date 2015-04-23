part of dslink.broker;

class BrokerNodeProvider extends NodeProviderImpl implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connName to connection
  final Map<String, RemoteLinkManager> conns =
      new Map<String, RemoteLinkManager>();

  LocalNodeImpl connsNode;
  Map rootStructure = {'conns': {}, 'defs': {}, 'quarantine': {}, 'sys': {}};
  BrokerNodeProvider() {
    // initialize root nodes
    RootNode root = new RootNode('/');
    nodes['/'] = root;
    root.load(rootStructure, this);
    connsNode = nodes['/conns'];
    _initSys();
  }
  
  void _initSys() {
    setNode('/sys/version', new BrokerVersionNode('/sys/version' ,'0.9.0'));
    setNode('/sys/startTime', new StartTimeNode('/sys/startTime'));
    setNode('/sys/clearConns', new ClearConnsAction('/sys/clearConns', this));
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
      m.forEach((String name, Map m){
        RemoteLinkRootNode node = getNode('/conns/$name');
        node.load(m, this);
        if (node.configs[r'$$dsId'] is String) {
          _id2connName[node.configs[r'$$dsId']] = name;
          _connName2id[name] = node.configs[r'$$dsId'];
        } else if (node.configs[r'$$deviceId'] is String) {
          _pendingDevices[node.configs[r'$$deviceId']] = name;
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
    connsFile.writeAsString(DsJson.encode(m));
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
  void setNode(String path, LocalNode newnode) {
    LocalNode node = nodes[path];
    if (node != null) {
      printError('error, BrokerNodeProvider.setNode same node can not be set twice');
      return;
    }
    
    Path p = new Path(path);
    LocalNode parentNode = nodes[p.parentPath];
    if (parentNode == null) {
      printError('error, BrokerNodeProvider.setNode parentNode is null');
      return;
    }
    
    nodes[path] = newnode;
    parentNode.addChild(p.name, newnode);
  }
  /// load a local node
  LocalNode getNode(String path) {
    LocalNode node = nodes[path];

    if (node != null) {
      return node;
    }

    if (path.startsWith('/conns/')) {
      String connName = path.split('/')[2];
      RemoteLinkManager conn = conns[connName];
      if (conn == null) {
        // TODO conn = new RemoteLinkManager('/conns/$connName', connRootNodeData);
        conn = new RemoteLinkManager(this, '/conns/$connName', this);
        conns[connName] = conn;
        nodes['/conns/$connName'] = conn.rootNode;
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
  final Map<String, String> _id2connName = new Map<String, String>();
  final Map<String, String> _connName2id = new Map<String, String>();

  String getConnName(String dsId) {
    if (_id2connName.containsKey(dsId)) {
      return _id2connName[dsId];
      // TODO is it possible same link get added twice?
    } else if (dsId.length < 43) {
      // user link
      String connName = dsId;
      int count = 0;
      // find a connName for it
      while (_connName2id.containsKey(connName)) {
        connName = '$dsId-${count++}';
      }
      _connName2id[connName] = dsId;
      _id2connName[dsId] = connName;
      return connName;
    } else {
      // device link
      String connName;
      
      // find a connName for it, keep append characters until find a new name
      int i = 43;
      if (dsId == '') i = 42;
      for (; i >= 0; --i) {
        connName = dsId.substring(0, dsId.length - i);
        if (i == 43 && connName.length > 1 && connName.endsWith('-')) {
          // remove the last - in the name;
          connName = connName.substring(0, connName.length-1);
        }
        if (!_connName2id.containsKey(connName)) {
          _connName2id[connName] = dsId;
          _id2connName[dsId] = connName;
          break;
        }
      }
      DsTimer.timerOnceAfter(saveConns, 3000);
      return connName;
    }
  }

  void addLink(ServerLink link) {
    String str = link.dsId;
    if (link.session != null) {
      str = '$str ${link.session}';
    }

    String connName;
    // TODO update children list of /conns node
    if (_links.containsKey(str)) {
      // TODO is it possible same link get added twice?
    } else {
      _links[str] = link;
      if (link.session == null){
        // don't create node for requester node with session
        connName = getConnName(str);
        getNode('/conns/$connName').configs[r'$$dsId'] = link.dsId;
        printLog('new node added at /conns/$connName');
      }
    }
  }
  /// [deviceId] is not a secure method of create link, only use it in https
  ServerLink getLink(String dsId, {String sessionId:'', String deviceId}) {
    if (deviceId != null && _pendingDevices.containsKey(deviceId)){
      _id2connName[dsId] = _pendingDevices[deviceId];
      _connName2id[_pendingDevices[deviceId]] = dsId;
      _pendingDevices.remove(deviceId);
      DsTimer.timerOnceAfter(saveConns, 3000);
    }
    String str = dsId;
    if (sessionId != null && sessionId != '') {
      str = '$dsId sessionId';
    }
    if (_links[str] != null) {
      String connName = getConnName(str);
      RemoteLinkNode node = getNode('/conns/$connName');
      var conn = node._linkManager;
      if (!conn.inTree) {
        connsNode.children[connName] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
        conn.inTree = true;
        connsNode.updateList(connName);
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
    String connName = getConnName(dsId);
    if (conns.containsKey(connName)) {
      return conns[connName].requester;
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getNode('/conns/$connName');
    return node._linkManager.requester;
  }

  Responder getResponder(String dsId, NodeProvider nodeProvider,
      [String sessionId = '']) {
    String connName = getConnName(dsId);
    if (conns.containsKey(connName)) {
      return conns[connName].getResponder(nodeProvider, sessionId);
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getNode('/conns/$connName');
    return node._linkManager.getResponder(nodeProvider, sessionId);
  }
}

part of dslink.broker;

class BrokerNodeProvider extends NodeProviderImpl implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connPath to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();

  BrokerPermissions permissions;

  IStorageManager storage;
//  Completer _done = new Completer();
//  Future get done => _done.future;

  String downstreamName;
  /// name with 1 slash
  String downstreamNameS;
  /// name with 2 slash
  String downstreamNameSS;
  
  RootNode root;
  BrokerNode connsNode;
  BrokerNode dataNode;
  BrokerNode usersNode;
  BrokerNode defsNode;
  BrokerNode upstreamDataNode;
  BrokerNode quarantineNode;
  BrokerNode tokens;
  
  Map rootStructure = {'users': {}, 'defs': {}, 'sys': {'tokens': {}}, 'upstream': {}};

  bool shouldSaveFiles = true;
  bool enabledQuarantine = false;
  bool enabledPermission = false;
  bool enabledDataNodes = false;
  bool acceptAllConns = true;
  
  BrokerNodeProvider({this.enabledQuarantine: false, this.acceptAllConns: true,
  List defaultPermission, this.downstreamName: 'conns', this.storage, this.enabledDataNodes:true}) {
    permissions = new BrokerPermissions();
    // initialize root nodes
    root = new RootNode('/', this);

    nodes['/'] = root;
    if (enabledQuarantine) {
      rootStructure['quarantine'] = {};
    }
    if (downstreamName == null ||
      downstreamName == '' ||
      rootStructure.containsKey(downstreamName) ||
      downstreamName.contains(Path.invalidNameChar)) {
      throw 'invalid downstreamName';
    }
    downstreamNameS = '/$downstreamName';
    downstreamNameSS = '$downstreamNameS/';
    rootStructure[downstreamName] = {};

    root.load(rootStructure);
    connsNode = nodes[downstreamNameS];
    connsNode.configs[r"$downstream"] = true;
    root.configs[r"$downstream"] = downstreamNameS;
    usersNode = nodes['/users'];
    dataNode = nodes['/data'];
    defsNode = nodes['/defs'];
    quarantineNode = nodes['/quarantine'];
    upstreamDataNode = nodes['/upstream'];
    tokens = nodes['/sys/tokens'];
    new BrokerQueryNode("/sys/query", this);

    enabledPermission = defaultPermission != null;
    
    if (enabledPermission) {
      root.loadPermission(
        defaultPermission); //['dgSuper','config','default','write']
      defsNode.loadPermission(['default', 'read']);
      permissions.root = root;
    }
  }
  loadAll() async {
    List<List<ISubscriptionNodeStorage>> storedData;
    if (storage != null) {
      storedData = await storage.loadSubscriptions();
    }
    await loadDef();
    registerInvokableProfile(userNodeFunctions);
    registerInvokableProfile(tokenNodeFunctions);
    initSys();
    await loadConns();
    await loadUserNodes();
    
    // tokens need to check if node still exists
    // load token after conns and userNodes are loaded 
    await loadTokensNodes();

    if (enabledDataNodes) {
      await loadDataNodes();
      registerInvokableProfile(dataNodeFunctions);
    }
    if (storedData != null) {
      for (List<ISubscriptionNodeStorage> nodeData in storedData) {
        if (nodeData.length > 0) {
          var nodeStorage = nodeData[0].storage;
          String path = nodeStorage.responderPath;
          if (path != null && conns.containsKey(path)) {
            conns[path].getResponder(this, null).initStorage(nodeStorage, nodeData);
          } else {
            nodeStorage.destroy();
          }
        }
      }
    }
  }
  void initSys() {
    new BrokerVersionNode("/sys/version", this, DSA_VERSION);
    new StartTimeNode("/sys/startTime", this);
    new ClearConnsAction("/sys/clearConns", this);

    ThroughPutController.initNodes(this);

    upstream = new UpstreamNode("/sys/upstream", this);

    BrokerTraceNode.init(this);
  }

  UpstreamNode upstream;

  bool _defsLoaded = false;

  /// load a fixed profile map
  loadDef() async {
    DefinitionNode profileNode = getOrCreateNode('/defs/profile', false);
    defsNode.children['profile'] = profileNode;
    defaultProfileMap.forEach((String name, Map m) {
      String path = '/defs/profile/$name';
      DefinitionNode node = getOrCreateNode(path, false);
      node.load(m);
      profileNode.children[name] = node;
    });
    File connsFile = new File("defs.json");
    try {
      String data = await connsFile.readAsString();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/defs/$name';
        DefinitionNode node = getOrCreateNode(path, false);
        node.load(m);
        defsNode.children[name] = node;
      });
    } catch (err) {}
  }

  void registerInvokableProfile(Map m) {
    void register(Map m, String path) {
      m.forEach((String key, Object val) {
        if (val is Map) {
          register(val, '$path$key/');
        } else if (val is InvokeCallback) {
          (getOrCreateNode('$path$key', false) as DefinitionNode)
            .setInvokeCallback(val);
        }
      });
    }
    register(m, '/defs/profile/');
  }

  loadUserNodes() async {
    File connsFile = new File("usernodes.json");
    try {
      String data = await connsFile.readAsString();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/users/$name';
        UserRootNode node = getOrCreateNode(path, false);
        if (enabledPermission) {
          node.loadPermission([[name, 'config'], ['default', 'none']]);
        }
        node.load(m);
        usersNode.children[name] = node;
        if (enabledQuarantine) {
          String path = '/quarantine/$name';
          BrokerNode node = getOrCreateNode(path, false);
          quarantineNode.children[name] = node;
        }
      });
    } catch (err) {}
  }

  Future<Map> saveUsrNodes() async {
    Map m = {};
    usersNode.children.forEach((String name, LocalNodeImpl node) {
      m[name] = node.serialize(true);
    });
    File connsFile = new File("usernodes.json");
    if (shouldSaveFiles) {
      await connsFile.writeAsString(DsJson.encode(m));
    }
    return m;
  }

  loadConns() async {
    // loadConns from file
    File connsFile = new File("conns.json");
    try {
      String data = await connsFile.readAsString();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '$downstreamNameSS$name';
        RemoteLinkRootNode node = getOrCreateNode(path, false);
        connsNode.children[name] = node;
        RemoteLinkManager conn = node._linkManager;
        conn.inTree = true;
        connsNode.updateList(name);

        node.load(m);
        if (node.configs[r'$$dsId'] is String) {
          _id2connPath[node.configs[r'$$dsId']] = path;
          _connPath2id[path] = node.configs[r'$$dsId'];
        }
      });
    } catch (err) {}
  }
  
  loadDataNodes() async {
    dataNode = new BrokerDataRoot('/data', this);
    root.children['data'] = dataNode;
    nodes['/data'] = dataNode;
    
    File connsFile = new File("data.json");
    try {
      String data = await connsFile.readAsString();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/data/$name';
        BrokerDataNode node = getOrCreateNode(path, true);
        node.load(m);
      });
    } catch (err) {}
    if (storage != null) {
       BrokerDataNode.storage = storage.getOrCreateValueStorageBucket('data');
       Map values = await BrokerDataNode.storage.load();
       values.forEach((key, val){
         if (nodes[key] is BrokerDataNode) {
           nodes[key].updateValue(val);
         } else {
           BrokerDataNode.storage.removeValue(key);
         }
       });
    }
  }
  Future<Map> saveDataNodes() async {
    Map m = {};
    dataNode.children.forEach((String name, BrokerDataNode node) {
      m[name] = node.serialize(true);
    });
    File connsFile = new File("data.json");
    if (shouldSaveFiles) {
      await connsFile.writeAsString(DsJson.encode(m));
    }
    return m;
  }
  loadTokensNodes() async {
    File connsFile = new File("tokens.json");
    try {
      String data = await connsFile.readAsString();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/sys/tokens/$name';
        TokenGroupNode tokens = new TokenGroupNode(path, this, name);
        tokens.load(m);
      });
    } catch (err) {
      String path = '/sys/tokens/root';
      TokenGroupNode tokens = new TokenGroupNode(path, this, 'root');
    }
    TokenGroupNode.initSecretToken(this);
  }
  Future<Map> saveTokensNodes() async {
    Map m = {};
    tokens.children.forEach((String name, TokenGroupNode node) {
      m[name] = node.serialize(true);
    });
    File connsFile = new File("tokens.json");
    if (shouldSaveFiles) {
      await connsFile.writeAsString(DsJson.encode(m));
    }
    return m;
  }
  Future<Map> saveConns() async {
    Map m = {};
    connsNode.children.forEach((String name, RemoteLinkNode node) {
      RemoteLinkManager manager = node._linkManager;
      m[name] = manager.rootNode.serialize(false);
    });
    File connsFile = new File("conns.json");
    if (shouldSaveFiles) {
      await connsFile.writeAsString(DsJson.encode(m));
    }
    return m;
  }

  // remove disconnected nodes from the conns node
  void clearConns() {
    List names = connsNode.children.keys.toList();
    for (String name in names) {
      RemoteLinkNode node = connsNode.children[name];
      RemoteLinkManager manager = node._linkManager;
      if (manager.disconnected != null) {
        String fullId = _connPath2id[manager.path];
        _connPath2id.remove(manager.path);
        _id2connPath.remove(fullId);
        connsNode.children.remove(name);
        manager.inTree = false;
        // remove server link if it's not connected
        if (_links.containsKey(fullId)) {
          _links.remove(fullId);
        }
        connsNode.updateList(name);
      }
    }
    DsTimer.timerOnceAfter(saveConns, 3000);
  }

  void clearUpstreamNodes() {
    List names = upstreamDataNode.children.keys.toList();
    for (String name in names) {
      var val = upstreamDataNode.children[name];
      if (val is! RemoteLinkNode) {
        continue;
      }

      RemoteLinkNode node = val;
      RemoteLinkManager manager = node._linkManager;
      if (manager.disconnected != null || !upstream.children.containsKey(name)) {
        String fullId = _connPath2id[manager.path];
        _connPath2id.remove(manager.path);
        _id2connPath.remove(fullId);
        upstreamDataNode.children.remove(name);
        manager.inTree = false;
        // remove server link if it's not connected
        if (_links.containsKey(fullId)) {
          _links.remove(fullId);
        }
        upstreamDataNode.updateList(name);
      }
    }
    DsTimer.timerOnceAfter(saveConns, 3000);
  }

  /// add a node to the tree
  void setNode(String path, LocalNode newNode) {
    LocalNode node = nodes[path];
    if (node != null) {
      logger.severe(
        'error, BrokerNodeProvider.setNode same node can not be set twice');
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

  LocalNode getNode(String path) {
    return nodes[path];
  }

  BrokerDataNode _getOrCreateDataNode(String path, [bool addToTree = true]) {
    BrokerDataNode node = nodes[path];
    if (node == null) {
      node = new BrokerDataNode(path, this);
      nodes[path] = node;
    }
    
    if (addToTree && node.parent == null) {
       int pos = path.lastIndexOf('/');
       String parentPath = path.substring(0,pos);
       String name = path.substring(pos + 1);
       
       BrokerDataNode parentNode = _getOrCreateDataNode(parentPath, true);
       parentNode.children[name] = node;
       node.parent = parentNode;
       parentNode.updateList(name);
       
     }
     return node;
  }
  LocalNode getOrCreateNode(String path, [bool addToTree = true]) {
    if (path.startsWith('/data/')) {
      return _getOrCreateDataNode(path, addToTree);
    }
    if (addToTree) {
      print('getOrCreateNode, addToTree = true, not supported');
    }
    LocalNode node = nodes[path];
    if (node != null) {
      return node;
    }
    if (path.startsWith('/users/')) {
      List paths = path.split('/');
      String username = path.split('/')[2];
      if (paths.length == 3) {
        node = new UserRootNode(path, username, this);
      } else {
        int pos = path.indexOf('/#');
        if (pos < 0) {
          node = new UserNode(path, this, username);
        } else {
          String connPath;
          int pos2 = path.indexOf('/', pos + 1);
          if (pos2 < 0) {
            connPath = path;
          } else {
            connPath = path.substring(0, pos2);
          }
          RemoteLinkManager conn = conns[connPath];
          if (conn == null) {
            // TODO conn = new RemoteLinkManager('$downstreamNameSS$connName', connRootNodeData);
            conn = new RemoteLinkManager(this, connPath, this);
            conns[connPath] = conn;
            nodes[connPath] = conn.rootNode;
            conn.rootNode.parentNode =
              getOrCreateNode(path.substring(0, pos), false);
          }
          node = conn.getOrCreateNode(path, false);
        }
      }
    } else if (path.startsWith(downstreamNameSS)) {
      String connName = path.split('/')[2];
      String connPath = '$downstreamNameSS$connName';
      RemoteLinkManager conn = conns[connPath];
      if (conn == null) {
        // TODO conn = new RemoteLinkManager('$downstreamNameSS$connName', connRootNodeData);
        conn = new RemoteLinkManager(this, connPath, this);
        conns[connPath] = conn;
        nodes[connPath] = conn.rootNode;
        conn.rootNode.parentNode = connsNode;
//        if (addToTree) {
//          connsNode.children[connName] = conn.rootNode;
//          conn.inTree = true;
//          connsNode.updateList(connName);
//        }
      }
      node = conn.getOrCreateNode(path, false);
    } else if (path.startsWith('/upstream/')) {
      String upstreamName = path.split('/')[2];
      String connPath = '/upstream/${upstreamName}';
      RemoteLinkManager conn = conns[connPath];
      if (conn == null) {
        conn = new RemoteLinkManager(this, connPath, this);
        conns[connPath] = conn;
        nodes[connPath] = conn.rootNode;

        conn.rootNode.parentNode = upstreamDataNode;
//        if (addToTree) {
//          upstreamDataNode.children[upstreamName] = conn.rootNode;
//          conn.inTree = true;
//          upstreamDataNode.updateList(upstreamName);
//        }
      }
      node = conn.getOrCreateNode(path, false);
    } else if (path.startsWith('/quarantine/')) {
      List paths = path.split('/');
      String user = paths[2];
      if (paths.length > 3) {
        String connName = paths[3];
        String connPath = '/quarantine/$user/$connName';
        RemoteLinkManager conn = conns[connPath];
        if (conn == null) {
          // TODO conn = new RemoteLinkManager('$downstreamNameSS$connName', connRootNodeData);
          conn = new RemoteLinkManager(this, connPath, this);
          conns[connPath] = conn;
          nodes[connPath] = conn.rootNode;
          BrokerNode quarantineUser =
          getOrCreateNode('/quarantine/$user', false);
          conn.rootNode.parentNode = quarantineUser;
//          if (addToTree) {
//            quarantineUser.children[connName] = conn.rootNode;
//            conn.inTree = true;
//            quarantineUser.updateList(connName);
//          }

        }
        node = conn.getOrCreateNode(path, false);
      } else {
        node = new BrokerNode(path, this);
      }
    } else if (path.startsWith('/defs/')) {
      //if (!_defsLoaded) {
      node = new DefinitionNode(path, this);
      //}
    } else {
      // TODO handle invalid node instead of allow everything
      node = new BrokerNode(path, this);
    }
    if (node != null) {
      nodes[path] = node;
    }
    return node;
  }
  
  bool clearNode(BrokerNode node){
    // TODO, keep it in memory if there are pending subscription
    // and remove it when subscription ends
    if (nodes[node.path] == node) {
      nodes.remove(node);
    }
    return true;
  }

  /// dsId to server links
  final Map<String, BaseLink> _links = new Map<String, BaseLink>();
  final Map<String, String> _id2connPath = new Map<String, String>();
  final Map<String, String> _connPath2id = new Map<String, String>();

  Map<String, String> get id2connPath => _id2connPath;
  Map<String, BaseLink> get links => _links;
  Map<String, String> get connPath2id => _connPath2id;

  RemoteLinkManager getConnById(String id) {
    if (_id2connPath.containsKey(id)) {
      return conns[_id2connPath[id]];
    }
    return null;
  }

  RemoteLinkManager getConnPath(String path) {
    return conns[path];
  }

  String makeConnPath(String fullId) {
    if (_id2connPath.containsKey(fullId)) {
      return _id2connPath[fullId];
      // TODO is it possible same link get added twice?
    } 
    
    if (fullId.startsWith('@upstream@')) {
      String connName = fullId.substring(10);
      String connPath = '/upstream/$connName';
      _connPath2id[connPath] = fullId;
      _id2connPath[fullId] = connPath;
      return connPath;
    }
    if (fullId.length < 43) {
      // user link
      String connPath = '$downstreamNameSS$fullId';
      int count = 0;
      // find a connName for it
      while (_connPath2id.containsKey(connPath)) {
        connPath = '$downstreamNameSS$fullId-${count++}';
      }
      _connPath2id[connPath] = fullId;
      _id2connPath[fullId] = connPath;
      return connPath;
    } else if (acceptAllConns) {
      // device link
      String connPath;
      String folderPath = downstreamNameSS;

      String dsId = fullId;
      if (fullId.contains(':')) {
        // uname:dsId
        List<String> u_id = fullId.split(':');
        folderPath = '/quarantine/${u_id[0]}/';
        dsId = u_id[1];
      }

      // find a connName for it, keep append characters until find a new name
      int i = 43;
      if (dsId.length == 43) i = 42;
      for (; i >= 0; --i) {
        connPath = '$folderPath${dsId.substring(0, dsId.length - i)}';
        if (i == 43 && connPath.length > 8 && connPath.endsWith('-')) {
          // remove the last - in the name;
          connPath = connPath.substring(0, connPath.length - 1);
        }
        if (!_connPath2id.containsKey(connPath)) {
          _connPath2id[connPath] = fullId;
          _id2connPath[fullId] = connPath;
          break;
        }
      }
      
      DsTimer.timerOnceBefore(saveConns, 3000);
      return connPath;
    } else {
      return null;
    }
  }
  String getLinkPath(String fullId, String token) {
    if (_id2connPath.containsKey(fullId)) {
      return _id2connPath[fullId];
    }
    if (token != null && token != '') {
      TokenNode tokenNode = TokenGroupNode.findTokenNode(token, fullId);
      if (tokenNode != null) {
        BrokerNode target = tokenNode.getTargetNode();
        
        String connPath;
        
        String folderPath = '${target.path}/';

        String dsId = fullId;


        // find a connName for it, keep append characters until find a new name
        int i = 43;
        if (dsId.length == 43) i = 42;
        for (; i >= 0; --i) {
          connPath = '$folderPath${dsId.substring(0, dsId.length - i)}';
          if (i == 43 && connPath.length > 8 && connPath.endsWith('-')) {
            // remove the last - in the name;
            connPath = connPath.substring(0, connPath.length - 1);
          }
          if (!_connPath2id.containsKey(connPath)) {
            _connPath2id[connPath] = fullId;
            _id2connPath[fullId] = connPath;
            break;
          }
        }
        tokenNode.useCount();
        DsTimer.timerOnceBefore(saveConns, 3000);
        return connPath;
      }
    }
    
    // fall back to normal path searching when it fails
    return makeConnPath(fullId);
  }
  void prepareUpstreamLink(String name) {
    String connPath = '/upstream/$name';
    String upStreamId = '@upstream@$name';
    _connPath2id[connPath] = upStreamId;
    _id2connPath[upStreamId] = connPath;
  }

  RemoteLinkManager addUpStreamLink(ClientLink link, String name) {
    String upStreamId = '@upstream@$name';
    RemoteLinkManager conn;
    // TODO update children list of /$downstreamNameS node
    if (_links.containsKey(upStreamId)) {
      // TODO is it possible same link get added twice?
      return null;
    } else {
      _links[upStreamId] = link;

      String connPath = '/upstream/$name';
      _connPath2id[connPath] = upStreamId;
      _id2connPath[upStreamId] = connPath;
      RemoteLinkNode node = getOrCreateNode(connPath, false);
      upstreamDataNode.children[name] = node;
      upstreamDataNode.updateList(name);

      conn = node._linkManager;
      conn.inTree = true;

      logger.info('new node added at $connPath');
    }

    if (!conn.inTree) {
      List paths = conn.path.split('/');
      String connName = paths.removeLast();
      BrokerNode parentNode = getOrCreateNode(paths.join('/'), false);
      parentNode.children[connName] = conn.rootNode;
      conn.rootNode.parentNode = parentNode;
      conn.inTree = true;
      parentNode.updateList(connName);
    }
    return conn;
  }

  bool addLink(ServerLink link) {
    String str = link.dsId;
    if (link.session != '' && link.session != null) {
      str = '$str ${link.session}';
    }

    String connPath;
    // TODO update children list of /$downstreamNameS node
    if (_links.containsKey(str)) {
      // TODO is it possible same link get added twice?
    } else {
      if (str.length >= 43 && (link.session == null || link.session == '')) {
        // don't create node for requester node with session
        connPath = makeConnPath(str);
        
        if (connPath != null) {
          var node = getOrCreateNode(connPath, false)
                    ..configs[r'$$dsId'] = str;
                  logger.info('new node added at $connPath');
                
        } else {
          return false;
        }
      }
      _links[str] = link;
    }
    return true;
  }

  ServerLink getLinkAndConnectNode(String dsId, {String sessionId: ''}) {
    if (sessionId == null) sessionId = '';
    String str = dsId;
    if (sessionId != null && sessionId != '') {
      // user link
      str = '$dsId ${sessionId}';
    } else if (_links[str] != null) {
      // add link to tree when it's not user link
      String connPath = makeConnPath(str);
      
      if (connPath == null) {
        // when link is not allowed, makeConnPath() returns null
        return null;
      }
      RemoteLinkNode node = getOrCreateNode(connPath, false);
      RemoteLinkManager conn = node._linkManager;
      if (!conn.inTree) {
        List paths = conn.path.split('/');
        String connName = paths.removeLast();
        BrokerNode parentNode = getOrCreateNode(paths.join('/'), false);
        parentNode.children[connName] = conn.rootNode;
        conn.rootNode.parentNode = parentNode;
        conn.inTree = true;
        parentNode.updateList(connName);
      }
    }
    return _links[str];
  }

  void removeLink(BaseLink link, String id, {bool force: false}) {
    if (_links[id] == link || force) {
      _links.remove(id);
    }
  }

  void updateLinkData(String dsId, Map m) {
    if (_id2connPath.containsKey(dsId)){
      var node = getOrCreateNode(_id2connPath[dsId]);
      node.configs[r'$linkData'] = m;
      //node.updateList(r'$linkData');
    }
  }
  
  Requester getRequester(String dsId) {
    String connPath = makeConnPath(dsId);
    if (connPath == null) return null;
    
    if (conns.containsKey(connPath)) {
      return conns[connPath].requester;
    }

    /// create the RemoteLinkManager
    RemoteLinkNode node = getOrCreateNode(connPath, false);
    return node._linkManager.requester;
  }

  Responder getResponder(String dsId, NodeProvider nodeProvider,
    [String sessionId = '']) {
    String connPath = makeConnPath(dsId);
    if (connPath == null) return null;
    RemoteLinkNode node = getOrCreateNode(connPath, false);
    Responder rslt = node._linkManager.getResponder(nodeProvider, dsId, sessionId);
    if (storage != null && sessionId == '' && rslt.storage == null) {
      rslt.storage = storage.getOrCreateSubscriptionStorage(connPath);
    }
    return rslt;
  }

  Responder createResponder(String dsId, String session) {
    return new Responder(this, dsId);
  }
}

part of dslink.broker;

class BrokerNodeProvider extends NodeProviderImpl implements ServerLinkManager {
  /// map that holds all nodes
  /// a node is not in parent node's children when real data/connection doesn't exist
  /// but instance is still there
  final Map<String, LocalNode> nodes = new Map<String, LocalNode>();

  /// connPath to connection
  final Map<String, RemoteLinkManager> conns = new Map<String, RemoteLinkManager>();

  BrokerPermissions permissions;

  String downstreamName;
  String downstreamNameS;
  String downstreamNameSS;
  BrokerNode connsNode;
  BrokerNode usersNode;
  BrokerNode defsNode;
  BrokerNode upstreamDataNode;
  BrokerNode quarantineNode;
  Map rootStructure = {'users':{},'defs': {}, 'sys': {}, 'upstream': {}};

  bool shouldSaveFiles = true;
  bool enabledQuarantine = false;
  bool enabledPermission = false;
  bool acceptAllConns = true;
  BrokerNodeProvider({this.enabledQuarantine:false, this.acceptAllConns:true, List defaultPermission, this.downstreamName:'conns'}) {
  
    permissions = new BrokerPermissions();
    // initialize root nodes
    RootNode root = new RootNode('/', this);

    nodes['/'] = root;
    if (enabledQuarantine) {
      rootStructure['quarantine'] = {};
    }
    if (downstreamName == null || downstreamName == '' || rootStructure.containsKey(downstreamName) || downstreamName.contains(Path.invalidNameChar)) {
      throw 'invalid downstreamName';
    }
    downstreamNameS = '/$downstreamName';
    downstreamNameSS = '$downstreamNameS/';
    rootStructure[downstreamName] = {};
    
    root.load(rootStructure);
    connsNode = nodes[downstreamNameS];
    usersNode = nodes['/users'];
    defsNode = nodes['/defs'];
    quarantineNode = nodes['/quarantine'];
    upstreamDataNode = nodes['/upstream'];

    enabledPermission = defaultPermission != null;
    if (enabledPermission) {
      root.loadPermission(defaultPermission);//['dgSuper','config','default','write']
      defsNode.loadPermission(['default','read']);
      permissions.root = root;
    }

    loadDef();
    registerInvokableProfile(userNodeFunctions);
    initSys();
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
  void loadDef() {
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
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/defs/$name';
        DefinitionNode node = getOrCreateNode(path,false);
        node.load(m);
        defsNode.children[name] = node;
      });
    } catch (err) {
    }
  }

  void registerInvokableProfile(Map m) {
    void register(Map m, String path) {
      m.forEach((String key, Object val) {
        if (val is Map) {
          register(val, '$path$key/');
        } else if (val is InvokeCallback) {
          (getOrCreateNode('$path$key', false) as DefinitionNode).setInvokeCallback(val);
        }
      });
    }
    register(m, '/defs/profile/');
  }

  void loadUserNodes() {
    File connsFile = new File("usernodes.json");
    try {
      String data = connsFile.readAsStringSync();
      Map m = DsJson.decode(data);
      m.forEach((String name, Map m) {
        String path = '/users/$name';
        UserRootNode node = getOrCreateNode(path, false);
        if (enabledPermission) {
          node.loadPermission([[name,'config'],['default','none']]);
        }
        node.load(m);
        usersNode.children[name] = node;
        if (enabledQuarantine) {
          String path = '/quarantine/$name';
          BrokerNode node = getOrCreateNode(path, false);
          quarantineNode.children[name] = node;
        }
      });
    } catch (err) {
    }
  }

  Map saveUsrNodes() {
    Map m = {};
    usersNode.children.forEach((String name, LocalNodeImpl node) {
      m[name] = node.serialize(true);
    });
    File connsFile = new File("usernodes.json");
    if (shouldSaveFiles) {
      connsFile.writeAsStringSync(DsJson.encode(m));
    }
    return m;
  }

  void loadConns() {
    // loadConns from file
    File connsFile = new File("conns.json");
    try {
      String data = connsFile.readAsStringSync();
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
    if (shouldSaveFiles) {
      connsFile.writeAsStringSync(DsJson.encode(m));
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


  LocalNode getNode(String path) {
    return nodes[path];
  }

  LocalNode getOrCreateNode(String path, [bool addToTree = true]) {
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
            conn.rootNode.parentNode = getOrCreateNode(path.substring(0, pos), false);
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
          BrokerNode quarantineUser = getOrCreateNode('/quarantine/$user', false);
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
      node = new BrokerNode(path, this);
    }
    if (node != null) {
      nodes[path] = node;
    }
    return node;
  }

  /// dsId to server links
  final Map<String, BaseLink> _links = new Map<String, BaseLink>();
  final Map<String, String> _id2connPath = new Map<String, String>();
  final Map<String, String> _connPath2id = new Map<String, String>();

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
    if (fullId.startsWith('@upstream@')){
      String connName = fullId.substring(10);
      String connPath = '/upstream/$connName';
      _connPath2id[connPath] = fullId;
      _id2connPath[fullId] = connPath;
      return connPath;
    }
    if (_id2connPath.containsKey(fullId)) {
      return _id2connPath[fullId];
      // TODO is it possible same link get added twice?
    } else if (fullId.length < 43) {
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
    } else {
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
    }
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
  void addLink(ServerLink link) {
    String str = link.dsId;
    if (link.session != '' && link.session != null) {
      str = '$str ${link.session}';
    }

    String connPath;
    // TODO update children list of /$downstreamNameS node
    if (_links.containsKey(str)) {
      // TODO is it possible same link get added twice?
    } else {
      _links[str] = link;
      if (link.session == null) {
        // don't create node for requester node with session
        connPath = makeConnPath(str);
        
        var node = getOrCreateNode(connPath, false)..configs[r'$$dsId'] = str;
        logger.info('new node added at $connPath');
      }
    }
  }

  ServerLink getLinkAndConnectNode(String dsId, {String sessionId:''}) {
    if (sessionId == null) sessionId = '';
    String str = dsId;
    if (sessionId != null && sessionId != '') {
      str = '$dsId ${sessionId}';
    }

    if (_links[str] != null) {
      String connPath = makeConnPath(str);
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

  void removeLink(BaseLink link, String id) {
    if (_links[id] == link) {
      _links.remove(id);
    }
  }

  Requester getRequester(String dsId) {
    String connPath = makeConnPath(dsId);
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
    if (conns.containsKey(connPath)) {
      return conns[connPath].getResponder(nodeProvider, dsId, sessionId);
    }
    /// create the RemoteLinkManager
    RemoteLinkNode node = getOrCreateNode(connPath, false);
    return node._linkManager.getResponder(nodeProvider, dsId, sessionId);
  }

  Responder createResponder(String dsId, String session) {
    return new Responder(this, dsId);
  }
}

part of dslink.broker;

class TokenGroupNode extends BrokerStaticNode {
  // a token map used by both global tokens, and user tokens
  static Map<String, TokenNode> tokens = new Map<String, TokenNode>();
  
  static TokenNode _trustedToken;
  static TokenNode get trustedToken => _trustedToken;
  static String initSecretToken(BrokerNodeProvider provider){
    String token = makeToken();
    String tokenId = token.substring(0, 16);
    TokenNode node = new TokenNode(null, provider, null, tokenId);
    node.configs[r'$$token'] = token;
    node.init();
    TokenGroupNode.tokens[tokenId] = node;
    _trustedToken = node;
    return token;
  }
  
  static String makeToken() {
    List<int> tokenCodes = new List<int>(48);
    int i = 0;
    while (i < 48) {
      int n = DSRandom.instance.nextUint8();
      if ((n >= 0x30 && n <= 0x39) ||
          (n >= 0x41 && n <= 0x5A) ||
          (n >= 0x61 && n <= 0x7A)) {
        tokenCodes[i] = n;
        i++;
      }
    }
    String rslt = new String.fromCharCodes(tokenCodes);
    String short = rslt.substring(0, 16);
    if (tokens.containsKey(short)) {
      return makeToken();
    }
    return rslt;
  }
  
  static TokenNode findTokenNode(String token, String dsId) {
    if (token.length < 16) {
      return null;
    }
    String tokenId = token.substring(0,16);
    String tokenHash = token.substring(16);
    if (!tokens.containsKey(tokenId)) {
      return null;
    }
    TokenNode tokenNode = tokens[tokenId];
    if (tokenNode.token == null) {
      return null;
    }
    String hashStr = CryptoProvider.sha256(UTF8.encode('$dsId${tokenNode.token}'));
    if (hashStr == tokenHash) {
      return tokenNode;
    }
    return null;
  }

  String groupId;
  TokenGroupNode(String path, BrokerNodeProvider provider, this.groupId)
      : super(path, provider) {
    configs[r'$is'] = 'broker/tokenGroup';
    profile =
        provider.getOrCreateNode('/defs/profile/broker/tokenGroup', false);
  }

  bool _loaded = false;
  void load(Map m) {
    if (_loaded) {
      configs.clear();
      attributes.clear();
      children.clear();
    }

    m.forEach((String key, value) {
      if (key.startsWith(r'$')) {
        configs[key] = value;
      } else if (key.startsWith('@')) {
        attributes[key] = value;
      } else if (value is Map) {
        TokenNode node = new TokenNode('$path/$key', provider, this, key);
        TokenGroupNode.tokens[key] = node;
        node.load(value);
        children[key] = node;
      }
    });
    _loaded = true;
  }
}

class TokenNode extends BrokerNode {
  int ts0 = -1;
  int ts1 = -1;
  int count = -1;
  TokenGroupNode parent;
  String id;
  String token;
  TokenNode(String path, BrokerNodeProvider provider, this.parent, this.id)
      : super(path, provider) {
    configs[r'$is'] = 'broker/token';
    profile = provider.getOrCreateNode('/defs/profile/broker/token', false);
    if (path != null) {
      // trustedTokenNode is not stored in the tree
      provider.setNode(path, this);
    }
  }
  void load(Map m) {
    super.load(m);
    init();
  }
  /// initialize timeRange and count
  void init() {
    if (configs[r'$$timeRange'] is String) {
      String s = configs[r'$$timeRange'];
      List dates = s.split('/');
      if (dates.length == 2) {
        try {
          ts0 = DateTime.parse(dates[0]).millisecondsSinceEpoch;
          ts1 = DateTime.parse(dates[1]).millisecondsSinceEpoch;
        } catch (err) {
          ts0 = -1;
          ts1 = -1;
        }
      }
    }
    if (configs[r'$$count'] is num) {
      count = (configs[r'$$count'] as num).toInt();
    }
    if (configs[r'$$token'] is String) {
      token = configs[r'$$token'];
    }
    //TODO implement target position
    //TODO when target position is gone, token should be removed
  }
  /// get the node where children should be connected
  BrokerNode getTargetNode(){
    // TODO, allow user to define the target node for his own token
    return provider.connsNode;
  }
}

InvokeResponse deleteTokenNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  if (parentNode is TokenNode) {
    parentNode.parent.children.remove(parentNode.id);
    TokenGroupNode.tokens.remove(parentNode.id);
    parentNode.parent.updateList(parentNode.id);
    parentNode.provider.clearNode(parentNode);

    DsTimer.timerOnceBefore(
        (responder.nodeProvider as BrokerNodeProvider).saveTokensNodes, 1000);
    return response..close();
  }
  return response..close(DSError.INVALID_PARAMETER);
}

InvokeResponse addTokenNode(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode) {
  if (parentNode is TokenGroupNode) {
    String token = TokenGroupNode.makeToken();
    String tokenId = token.substring(0, 16);
    TokenNode node = new TokenNode('${parentNode.path}/$tokenId',
        parentNode.provider, parentNode, tokenId);
    node.configs[r'$$timeRange'] = params['timeRange'];
    node.configs[r'$$count'] = params['count'];
    node.configs[r'$$token'] = token;
    node.init();
    TokenGroupNode.tokens[tokenId] = node;
    parentNode.children[tokenId] = node;
    parentNode.updateList(tokenId);

    response.updateStream([[token]], streamStatus: StreamStatus.closed);
    DsTimer.timerOnceBefore(
        (responder.nodeProvider as BrokerNodeProvider).saveTokensNodes, 1000);
    return response;
  }
  return response..close(DSError.INVALID_PARAMETER);
}

Map tokenNodeFunctions = {
  "broker": {
    "token": {"delete": deleteTokenNode},
    "tokenGroup": {"add": addTokenNode}
  }
};

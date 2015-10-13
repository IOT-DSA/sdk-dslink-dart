part of dslink.broker;

class TokenGroupNode extends BrokerStaticNode {
  // a token map used by both global tokens, and user tokens
  static Map<String, TokenNode> tokens = new Map<String, TokenNode>();
  static String makeTokeId() {
    List<int> tokenCodes = new List<int>(32);
    int i = 0;
    while (i < 32) {
      int n = DSRandom.instance.nextUint8();
      if ((n >= 0x30 && n <= 0x39) ||
          (n >= 0x41 && n <= 0x5A) ||
          (n >= 0x61 && n <= 0x7A)) {
        tokenCodes[i] = n;
        i++;
      }
    }
    String rslt = new String.fromCharCodes(tokenCodes);
    if (tokens.containsKey(rslt)) {
      return makeTokeId();
    }
    return rslt;
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



class TokenNode extends BrokerStaticNode {
  int ts0 = -1;
  int ts1 = -1;
  int count = -1;
  TokenGroupNode parent;
  String id;
  TokenNode(String path, BrokerNodeProvider provider, this.parent, this.id)
      : super(path, provider) {
    configs[r'$is'] = 'broker/token';
    profile = provider.getOrCreateNode('/defs/profile/broker/token', false);
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
        try{
          ts0 = DateTime.parse(dates[0]).millisecondsSinceEpoch;
          ts1 = DateTime.parse(dates[1]).millisecondsSinceEpoch;
        } catch(err) {
          ts0 = -1;
          ts1 = -1;
        }
      }
    }
    if (configs[r'$$count'] is num) {
      count = (configs[r'$$count'] as num).toInt();
    }
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
    String tokenId = TokenGroupNode.makeTokeId();
    TokenNode node = new TokenNode(
        '${parentNode.path}/$tokenId', parentNode.provider, parentNode, tokenId);
    node.configs[r'$$timeRange'] = params['timeRange'];
    node.configs[r'$$count'] = params['count'];
    node.init();
    TokenGroupNode.tokens[tokenId] = node;
    parentNode.children[tokenId] = node;
    parentNode.updateList(tokenId);

    //TODO
    response.updateStream([[tokenId]], streamStatus: StreamStatus.closed);
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

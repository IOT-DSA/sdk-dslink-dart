part of dslink.broker;

class TokensNode extends BrokerStaticNode {
  IValueStorageBucket storage;
  TokensNode(String path, BrokerNodeProvider provider, this.storage) : super(path, provider) {
    
  }
  
  loadTokens() async{
    Map tokensData = await storage.load();
  }
}

class TokenNode extends BrokerNode {
  TokenNode(String path, BrokerNodeProvider provider) : super(path, provider);
  
}
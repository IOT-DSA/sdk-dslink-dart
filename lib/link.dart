library dslink.link;

import "dart:async";
import "dart:io";

import "package:dslink/http_client.dart";
import "package:dslink/src/http/websocket_conn.dart";
import "package:dslink/common.dart";
import "package:dslink/src/crypto/pk.dart";
import "package:dslink/responder.dart";

export "package:dslink/src/crypto/pk.dart" show PrivateKey;

class Link {
  final String host;
  final int port;
  final PrivateKey privateKey;
  
  HttpClientSession session;
  
  
  _NodeProvider _nodeProvider;
  
  Link(this.host, this.privateKey, {this.port: 80}) {
    _nodeProvider = new _NodeProvider(this);
  }
  
  void addRootNode(ResponderNode node) {
    rootNode.addChild(node);
  }
  
  Future connect() async {
    session = new HttpClientSession("${host}:${port}", "broker-dsa", new PrivateKey.generate(), nodeProvider: _nodeProvider);
    await session.init();
  }
  
  BaseNode rootNode = new BaseNode("/");
}

class _NodeProvider extends NodeProvider {
  final Link link;
  
  _NodeProvider(this.link);
  
  @override
  ResponderNode getNode(String path) {
    var node = link.rootNode;
    var parts = path.split("/");
    int i = 0;
    while (node != null && node.path != path) {
      node = node.getChild(parts[i]);
      i++;
    }
    return node;
  }
}

class BaseNode extends ResponderNode {
  List<SubscribeResponse> _subscribers;
  Object _value;
  
  BaseNode(String path) : super(path);
  
  @override
  bool get exists => true;

  @override
  Response invoke(Map params, Responder responder, Response response) {
    return null;
  }

  @override
  Response list(Responder responder, Response response) {
    return null;
  }

  @override
  Response removeAttribute(String name, Responder responder, Response response) {
    attributes.remove(name);
    return response..close();
  }

  @override
  Response removeConfig(String name, Responder responder, Response response) {
    configs.remove(name);
    return response..close();
  }

  @override
  Response setAttribute(String name, String value, Responder responder, Response response) {
    attributes[name] = value;
    return response..close();
  }

  @override
  Response setConfig(String name, Object value, Responder responder, Response response) {
    configs[name] = value;
    return response..close();
  }

  @override
  Response setValue(Object value, Responder responder, Response response) {
    _value = value;
    return response..close();
  }

  @override
  void subscribe(SubscribeResponse subscription, Responder responder) {
    _subscribers.add(subscription);
    subscription.close();
  }

  @override
  void unsubscribe(SubscribeResponse subscription, Responder responder) {
    _subscribers.remove(subscription);
    subscription.close();
  }
}
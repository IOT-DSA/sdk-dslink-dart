library dslink.link;

import "package:dslink/common.dart";
import "package:dslink/responder.dart";

class DsLink {
  final DsConnectionChannel connection;
  _NodeProvider nodeProvider;
  DsResponder responder;
  
  DsLink(this.connection) {
    nodeProvider = new _NodeProvider(this);
    responder = new DsResponder(nodeProvider);
    responder.connection = connection;
  }
  
  BaseNode rootNode = new BaseNode("/");
}

class _NodeProvider extends DsNodeProvider {
  final DsLink link;
  
  _NodeProvider(this.link);
  
  @override
  DsRespNode getNode(String path) {
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

class BaseNode extends DsRespNode {
  List<DsSubscribeResponse> _subscribers;
  Object _value;
  
  BaseNode(String path) : super(path);
  
  @override
  bool get exists => true;

  @override
  DsResponse invoke(Map params, DsResponder responder, int rid) {
    return null;
  }

  @override
  DsResponse list(DsResponder responder, int rid) {
    var resp = new DsResponse(responder, rid);
    return null;
  }

  @override
  DsResponse removeAttribute(String name, DsResponder responder, int rid) {
    attributes.remove(name);
    return new DsResponse(responder, rid)..close();
  }

  @override
  DsResponse removeConfig(String name, DsResponder responder, int rid) {
    configs.remove(name);
    return new DsResponse(responder, rid)..close();
  }

  @override
  DsResponse setAttribute(String name, String value, DsResponder responder, int rid) {
    attributes[name] = value;
    return new DsResponse(responder, rid)..close();
  }

  @override
  DsResponse setConfig(String name, Object value, DsResponder responder, int rid) {
    configs[name] = value;
    return new DsResponse(responder, rid)..close();
  }

  @override
  DsResponse setValue(Object value, DsResponder responder, int rid) {
    _value = value;
    return new DsResponse(responder, rid)..close();
  }

  @override
  void subscribe(DsSubscribeResponse subscription, DsResponder responder) {
    _subscribers.add(subscription);
    subscription.close();
  }

  @override
  void unsubscribe(DsSubscribeResponse subscription, DsResponder responder) {
    _subscribers.remove(subscription);
    subscription.close();
  }
}
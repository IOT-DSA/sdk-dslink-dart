part of dslink.responder;

/// node can be subscribed or listed by multiple responder
abstract class ResponderNode extends Node {
  ResponderNode(String path) : super(path);

  /// list and subscribe can be called on a node that doesn't exist
  /// other api like set remove, invoke, can only be applied to existing node
  bool get exists;

  Response list(Responder responder, Response response);
  RespSubscribeController subscribe(SubscribeResponse subscription, Responder responder);

  Response invoke(Map params, Responder responder, Response rid);

  Response setAttribute(String name, String value, Responder responder, Response rid);
  Response removeAttribute(String name, Responder responder, Response rid);
  Response setConfig(String name, Object value, Responder responder, Response rid);
  Response removeConfig(String name, Responder responder, Response rid);
  /// set node value
  Response setValue(Object value, Responder responder, Response rid);
}
/// node provider for responder
/// one nodeProvider can be reused by multiple responders
abstract class NodeProvider {
  /// get a existing node or create a dummy node for requester to listen on
  ResponderNode getNode(String path);
}

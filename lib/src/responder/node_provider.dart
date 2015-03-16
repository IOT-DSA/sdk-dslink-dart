part of dslink.responder;

/// node can be subscribed or listed by multiple responder
abstract class LocalNode extends Node {
  final StreamController<String> listChangeController =
      new StreamController<String>();

  Stream<String> _listStream;

  Stream<String> get listStream {
    if (_listStream == null) {
      _listStream = listChangeController.stream.asBroadcastStream();
    }
    return _listStream;
  }

  StreamController<ValueUpdate> _valueController;

  StreamController<ValueUpdate> get valueController {
    // lazy initialize
    if (_valueController == null) {
      _valueController = new StreamController<ValueUpdate>();
    }
    return _valueController;
  }

  Stream<ValueUpdate> _valueStream;

  Stream<ValueUpdate> get valueStream {
    if (_valueStream == null) {
      _valueStream = valueController.stream.asBroadcastStream();
    }
    return _valueStream;
  }

  ValueUpdate _lastValueUpdate;
  ValueUpdate get lastValueUpdate {
    if (_lastValueUpdate == null) {
      _lastValueUpdate = new ValueUpdate(null);
    }
    return _lastValueUpdate;
  }

  void updateValue(Object update) {
    if (update is ValueUpdate) {
      _lastValueUpdate = update;
      if (_valueController != null) {
        _valueController.add(_lastValueUpdate);
      }
    } else if (_lastValueUpdate == null || _lastValueUpdate.value != update) {
      _lastValueUpdate = new ValueUpdate(update);
      if (_valueController != null) {
        _valueController.add(_lastValueUpdate);
      }
    }
  }
  /// get a list of permission setting on this node
  PermissionList get permissions => null;
  /// get the permission of a responder (actually the permisison of the linked requester)
  int getPermission(Responder responder) {
    return Permission.READ;
  }
  final String path;
  LocalNode(this.path);

  /// list and subscribe can be called on a node that doesn't exist
  /// other api like set remove, invoke, can only be applied to existing node
  bool get exists => true;

  /// whether the node is ready for returning a list response
  bool get listReady => true;

  InvokeResponse invoke(
      Map params, Responder responder, InvokeResponse response) {
    return response..close();
  }

  Response setAttribute(
      String name, String value, Responder responder, Response response) {
    return response..close();
  }

  Response removeAttribute(
      String name, Responder responder, Response response) {
    return response..close();
  }

  Response setConfig(
      String name, Object value, Responder responder, Response response) {
    return response..close();
  }

  Response removeConfig(String name, Responder responder, Response response) {
    return response..close();
  }
  /// set node value
  Response setValue(Object value, Responder responder, Response response) {
    return response..close();
  }
}
/// node provider for responder
/// one nodeProvider can be reused by multiple responders
abstract class NodeProvider {
  /// get a existing node or create a dummy node for requester to listen on
  LocalNode getNode(String path);
}

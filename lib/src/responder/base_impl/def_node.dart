part of dslink.responder;

typedef InvokeResponse InvokeCallback(Map params, Responder responder,
    InvokeResponse response, LocalNode parentNode);

/// definition nodes are serializable node that won"t change
/// the only change will be a global upgrade
class DefinitionNode extends LocalNodeImpl {
  final NodeProvider provider;

  DefinitionNode(String path, this.provider) : super(path) {
    this.configs[r"$is"] = "static";
  }

  InvokeCallback _invokeCallback;

  void setInvokeCallback(InvokeCallback callback) {
    _invokeCallback = callback;
  }

  @override
  InvokeResponse invoke(
    Map<String, dynamic> params,
    Responder responder,
    InvokeResponse response,
    Node parentNode,
    [int maxPermission = Permission.CONFIG]) {
    if (_invokeCallback == null) {
      return response..close(DSError.NOT_IMPLEMENTED);
    }

    String parentPath = parentNode is LocalNode ? parentNode.path : null;

    int permission = responder.nodeProvider.permissions.getPermission(
      parentPath,
      responder
    );

    if (maxPermission < permission) {
      permission = maxPermission;
    }

    if (getInvokePermission() <= permission) {
      _invokeCallback(params, responder, response, parentNode);
      return response;
    } else {
      return response..close(DSError.PERMISSION_DENIED);
    }

    return response..close();
  }
}

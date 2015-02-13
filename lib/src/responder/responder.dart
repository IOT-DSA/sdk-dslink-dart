part of dslink.responder;

/// a responder for one connection
class Responder extends ConnectionHandler {

  /// reqId can be a dsId or a user name
  String reqId;
  /// list of permission group
  List<String> groups = [];

  final Map<int, Response> _responses = new Map<int, Response>();
  SubscribeResponse _subscription;
  /// caching of nodes
  final NodeProvider nodeProvider;

  Responder(this.nodeProvider) {
    _subscription = new SubscribeResponse(this, 0);
    _responses[0] = _subscription;
  }
  Response addResponse(Response response) {
    if (response._streamStatus != StreamStatus.closed) {
      _responses[response.rid] = response;
    }
    return response;
  }

  void onData(List list) {
    for (Object resp in list) {
      if (resp is Map) {
        _onReceiveRequest(resp);
      }
    }
  }

  void _onReceiveRequest(Map m) {
    if (m['method'] is String && m['rid'] is int) {
      if (_responses.containsKey(m['rid'])) {
        if (m['method'] == 'close') {
          _close(m);
        }
        // when rid is invalid, nothing needs to be sent back
        return;
      }
      switch (m['method']) {
        case 'list':
          _list(m);
          return;
        case 'subscribe':
          _subscribe(m);
          return;
        case 'unsubscribe':
          _unsubscribe(m);
          return;
        case 'invoke':
          _invoke(m);
          return;
        case 'set':
          _set(m);
          return;
        case 'remove':
          _remove(m);
          return;
        default:
      }
    }
    if (m['rid'] is int) {
      _closeResponse(m['rid'], error: DSError.INVALID_METHOD);
    }
  }
  /// close the response from responder side and notify requester
  void _closeResponse(int rid, {Response response, DSError error}) {
    if (response != null) {
      if (_responses[response.rid] != response) {
        // this response is no longer valid
        return;
      }
      response._streamStatus = StreamStatus.closed;
      rid = response.rid;
    }
    Map m = {
      'rid': rid,
      'stream': StreamStatus.closed
    };
    if (error != null) {
      m['error'] = error.serialize();
    }
    addToSendList(m);
  }

  void updateReponse(Response response, List updates, {String streamStatus, List<TableColumn> columns}) {
    if (_responses[response.rid] == response) {
      Map m = {
        'rid': response.rid
      };
      if (streamStatus != null && streamStatus != response._streamStatus) {
        response._streamStatus = streamStatus;
        m['stream'] = streamStatus;
      }
      if (columns != null) {
        m['columns'] = columns;
      }
      if (updates != null) {
        m['updates'] = updates;
      }
      addToSendList(m);
      if (response._streamStatus == StreamStatus.closed) {
        _responses.remove(response.rid);
      }
    }
  }

  void _list(Map m) {
    Path path = Path.getValidNodePath(m['path']);
    if (path != null && path.absolute) {
      int rid = m['rid'];
      var node = nodeProvider.getNode(path.path);
      addResponse(new ListResponse(this, rid, node));
    } else {
      _closeResponse(m['rid'], error: DSError.INVALID_PATH);
    }
  }
  void _subscribe(Map m) {
    if (m['paths'] is List) {
      int rid = m['rid'];
      for (Object str in m['paths']) {
        Path path = Path.getValidNodePath(str);
        if (path != null && path.absolute) {
          _subscription.add(path.path, new RespSubscribeController(_subscription, nodeProvider.getNode(path.path)));
        }
      }
      _closeResponse(m['rid']);
    } else {
      _closeResponse(m['rid'], error: DSError.INVALID_PATHS);
    }
  }
  void _unsubscribe(Map m) {
    if (m['paths'] is List) {
      int rid = m['rid'];
      for (Object str in m['paths']) {
        Path path = Path.getValidNodePath(str);
        if (path != null && path.absolute) {
          _subscription.remove(path.path);
        }
      }
      _closeResponse(m['rid']);
    } else {
      _closeResponse(m['rid'], error: DSError.INVALID_PATHS);
    }
  }
  void _invoke(Map m) {
    Path path = Path.getValidNodePath(m['path']);
    if (path != null && path.absolute) {
      int rid = m['rid'];
      Map params = {};
      if (m['params'] is Map) {
        (m['params'] as Map).forEach((key, value) {
          // only allow primitive types in parameters
          if (value is! List && value is! Map) {
            params[key] = value;
          }
        });
      }
      var node = nodeProvider.getNode(path.path);
      node.invoke(params, this, addResponse(new InvokeResponse(this, rid, node)));
    } else {
      _closeResponse(m['rid'], error: DSError.INVALID_PATH);
    }
  }
  void _set(Map m) {
    Path path = Path.getValidPath(m['path']);
    if (path == null || !path.absolute) {
      _closeResponse(m['rid'], error: DSError.INVALID_PATH);
      return;
    }
    if (!m.containsKey('value')) {
      _closeResponse(m['rid'], error: DSError.INVALID_VALUE);
      return;
    }
    Object value = m['value'];
    int rid = m['rid'];
    if (path.isNode) {
      nodeProvider.getNode(path.path).setValue(value, this, addResponse(new Response(this, rid)));
    } else if (path.isConfig) {
      nodeProvider.getNode(path.parentPath).setConfig(path.name, value, this, addResponse(new Response(this, rid)));
    } else if (path.isAttribute) {
      if (value is String) {
        nodeProvider.getNode(path.parentPath).setAttribute(path.name, value, this, addResponse(new Response(this, rid)));
      } else {
        _closeResponse(m['rid'], error: DSError.INVALID_VALUE);
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void _remove(Map m) {
    Path path = Path.getValidPath(m['path']);
    if (path == null || path.absolute) {
      _closeResponse(m['rid'], error: DSError.INVALID_PATH);
      return;
    }
    int rid = m['rid'];
    if (path.isNode) {
      _closeResponse(m['rid'], error: DSError.INVALID_METHOD);
    } else if (path.isConfig) {
      nodeProvider.getNode(path.parentPath).removeConfig(path.name, this, addResponse(new Response(this, rid)));
    } else if (path.isAttribute) {
      nodeProvider.getNode(path.parentPath).removeAttribute(path.name, this, addResponse(new Response(this, rid)));
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void _close(Map m) {
    if (m['rid'] is int) {
      int rid = m['rid'];
      if (_responses.containsKey(rid)) {
        _responses[rid]._close();
        _responses.remove(rid);
      }
    }
  }

  void onDisconnected() {
    _responses.forEach((id, resp) {
      resp._close();
    });
    _responses.clear();
    _responses[0] = _subscription;
  }

  void onReconnected() {}
}

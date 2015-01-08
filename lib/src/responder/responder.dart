part of dslink.responder;

/// a responder for one connection
class DsResponder {
  final DsConnection conn;
  final Map<int, DsResponse> _responses = new Map<int, DsResponse>();
  DsSubscribeResponse _subscription;
  /// caching of nodes
  final DsNodeProvider nodeProvider;

  DsResponder(this.conn, this.nodeProvider) {
    _subscription = new DsSubscribeResponse(this, 0);
    _responses[0] = _subscription;

    conn.onReceive.listen(_onData);
  }
  void addResponse(DsResponse response) {
    if (response.streamStatus != DsStreamStatus.closed) {
      _responses[response.rid] = response;
    }
  }
  void _onData(Map m) {
    if (m['method'] is String && m['rid'] is int) {
      if (_responses.containsKey(m['rid'])) {
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
        case 'close':
          _close(m);
          return;
        default:
      }
    }
    if (m['rid'] is int) {
      _closeResponse(m['rid'], new DsError('invalid request method'));
    }
  }
  /// close the response from responder side and notify requester
  void _closeResponse(int rid, [DsError err]) {
    Map m = {
      'rid': rid,
      'stream': DsStreamStatus.closed
    };
    if (err != null) {
      m['error'] = err.serialize();
    }
    conn.send(m);
  }


  void _list(Map m) {
    DsPath path = DsPath.getValidNodePath(m['path']);
    if (path != null && path.absolute) {
      int rid = m['rid'];
      addResponse(nodeProvider.getNode(path.path).list(this, rid));
    } else {
      _closeResponse(m['rid'], new DsError('invalid path'));
    }
  }
  void _subscribe(Map m) {
    if (m['paths'] is List) {
      int rid = m['rid'];
      for (Object str in m['paths']) {
        DsPath path = DsPath.getValidNodePath(m['str']);
        if (path != null && path.absolute) {
          nodeProvider.getNode(path.path).subscribe(_subscription, this);
        }
      }
      _closeResponse(m['rid']);
    } else {
      _closeResponse(m['rid'], new DsError('invalid paths'));
    }
  }
  void _unsubscribe(Map m) {
    if (m['paths'] is List) {
      int rid = m['rid'];
      for (Object str in m['paths']) {
        DsPath path = DsPath.getValidNodePath(m['str']);
        if (path != null && path.absolute) {
          nodeProvider.getNode(path.path).unsubscribe(_subscription, this);
        }
      }
      _closeResponse(m['rid']);
    } else {
      _closeResponse(m['rid'], new DsError('invalid paths'));
    }
  }
  void _invoke(Map m) {
    DsPath path = DsPath.getValidNodePath(m['path']);
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
      addResponse(nodeProvider.getNode(path.path).invoke(params, this, rid));
    } else {
      _closeResponse(m['rid'], new DsError('invalid path'));
    }
  }
  void _set(Map m) {
    DsPath path = DsPath.getValidPath(m['path']);
    if (path == null || path.absolute) {
      _closeResponse(m['rid'], new DsError('invalid path'));
      return;
    }
    if (!m.containsKey('value')) {
      _closeResponse(m['rid'], new DsError('missing value'));
      return;
    }
    Object value = m['value'];
    int rid = m['rid'];
    if (path.isNode) {
      addResponse(nodeProvider.getNode(path.path).setValue(value, this, rid));
    } else if (path.isConfig) {
      addResponse(nodeProvider.getNode(path.parentPath).setConfig(path.name, value, this, rid));
    } else if (path.isAttribute) {
      if (value is String) {
        addResponse(nodeProvider.getNode(path.parentPath).setAttribute(path.name, value, this, rid));
      } else {
        _closeResponse(m['rid'], new DsError('attribute value must be string'));
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void _remove(Map m) {
    DsPath path = DsPath.getValidPath(m['path']);
    if (path == null || path.absolute) {
      _closeResponse(m['rid'], new DsError('invalid path'));
      return;
    }
    int rid = m['rid'];
    if (path.isNode) {
      _closeResponse(m['rid'], new DsError('can not remove a node'));
    } else if (path.isConfig) {
      addResponse(nodeProvider.getNode(path.parentPath).removeConfig(path.name, this, rid));
    } else if (path.isAttribute) {
      addResponse(nodeProvider.getNode(path.parentPath).removeAttribute(path.name, this, rid));
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
}

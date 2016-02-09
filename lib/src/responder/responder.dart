part of dslink.responder;

/// a responder for one connection
class Responder extends ConnectionHandler {
  /// reqId can be a dsId or a user name
  String reqId;

  int maxCacheLength = ConnectionProcessor.DEFAULT_CACHE_SIZE;

  ISubscriptionResponderStorage storage;

  void initStorage(ISubscriptionResponderStorage s, List<ISubscriptionNodeStorage> nodes) {
    if (storage != null) {
      storage.destroy();
    }
    storage = s;
    if (storage != null && nodes != null) {
      for (ISubscriptionNodeStorage node in nodes) {
        var values = node.getLoadedValues();
        LocalNode localnode = nodeProvider.getOrCreateNode(node.path, false);
        RespSubscribeController controller = _subscription.add(
          node.path,
          localnode,
          -1,
          node.qos
        );

        if (values.isNotEmpty) {
          controller.resetCache(values);
        }
      }
    }
  }

  /// list of permission group
  List<String> groups = [];
  void updateGroups(List<String> vals) {
    if (reqId != null && reqId.length < 43 && !vals.contains(reqId)) {
      groups = [reqId]..addAll(vals);
    }
  }

  final Map<int, Response> _responses =
    new LeakProofMap<int, Response>.create("responder responses");

  SubscribeResponse _subscription;

  /// caching of nodes
  final NodeProvider nodeProvider;

  Responder(this.nodeProvider, [this.reqId]) {
    _subscription = new SubscribeResponse(this, 0);
    _responses[0] = _subscription;
    // TODO: load reqId
    if (reqId != null && reqId.length < 43) {
      groups = [reqId];
    }
  }

  Response addResponse(Response response) {
    if (response._sentStreamStatus != StreamStatus.closed) {
      _responses[response.rid] = response;
      if (_traceCallbacks != null) {
        ResponseTrace update = response.getTraceData();
        for (ResponseTraceCallback callback in _traceCallbacks) {
          callback(update);
        }
      }
    } else {
      if (_traceCallbacks != null) {
        ResponseTrace update = response.getTraceData(''); // no logged change is needed
        for (ResponseTraceCallback callback in _traceCallbacks) {
          callback(update);
        }
      }
    }
    return response;
  }

  void traceResponseRemoved(Response response){
    ResponseTrace update = response.getTraceData('-');
    for (ResponseTraceCallback callback in _traceCallbacks) {
      callback(update);
    }
  }

  void onData(List list) {
    for (Object resp in list) {
      if (resp is Map) {
        _onReceiveRequest(resp);
      }
    }
  }

  void _onReceiveRequest(Map m) {
    Object method = m['method'];
    if (m['rid'] is int) {
      if (method == null) {
        updateInvoke(m);
        return;
      } else {
        if (_responses.containsKey(m['rid'])) {
          if (method == 'close') {
            close(m);
          }
          // when rid is invalid, nothing needs to be sent back
          return;
        }

        switch (method) {
          case 'list':
            list(m);
            return;
          case 'subscribe':
            subscribe(m);
            return;
          case 'unsubscribe':
            unsubscribe(m);
            return;
          case 'invoke':
            invoke(m);
            return;
          case 'set':
            set(m);
            return;
          case 'remove':
            remove(m);
            return;
        }
      }
    }
    closeResponse(m['rid'], error: DSError.INVALID_METHOD);
  }

  /// close the response from responder side and notify requester
  void closeResponse(int rid, {Response response, DSError error}) {
    if (response != null) {
      if (_responses[response.rid] != response) {
        // this response is no longer valid
        return;
      }
      response._sentStreamStatus = StreamStatus.closed;
      rid = response.rid;
    }
    Map m = {'rid': rid, 'stream': StreamStatus.closed};
    if (error != null) {
      m['error'] = error.serialize();
    }
    _responses.remove(rid);
    addToSendList(m);
  }

  void updateResponse(Response response, List updates,
      {
        String streamStatus,
        List<TableColumn> columns,
        Map meta,
        void handleMap(Map m)}) {
    if (_responses[response.rid] == response) {
      Map m = {'rid': response.rid};
      if (streamStatus != null && streamStatus != response._sentStreamStatus) {
        response._sentStreamStatus = streamStatus;
        m['stream'] = streamStatus;
      }

      if (columns != null) {
        m['columns'] = columns;
      }

      if (updates != null) {
        m['updates'] = updates;
      }

      if (meta != null) {
        m['meta'] = meta;
      }

      if (handleMap != null) {
        handleMap(m);
      }

      addToSendList(m);
      if (response._sentStreamStatus == StreamStatus.closed) {
        _responses.remove(response.rid);
        if (_traceCallbacks != null) {
          traceResponseRemoved(response);
        }
      }
    }
  }

  void list(Map m) {
    Path path = Path.getValidNodePath(m['path']);
    if (path != null && path.isAbsolute) {
      int rid = m['rid'];

      _getNode(path, (LocalNode node) {
        addResponse(new ListResponse(this, rid, node));
      }, (e, stack) {
        var error = new DSError(
          "nodeError",
          msg: e.toString(),
          detail: stack.toString()
        );
        closeResponse(m['rid'], error: error);
      });
    } else {
      closeResponse(m['rid'], error: DSError.INVALID_PATH);
    }
  }

  void subscribe(Map m) {
    if (m['paths'] is List) {
      for (Object p in m['paths']) {
        String pathstr;
        int qos = 0;
        int sid = -1;
        if (p is Map) {
          if (p['path'] is String) {
            pathstr = p['path'];
          } else {
            continue;
          }
          if (p['sid'] is int) {
            sid = p['sid'];
          } else {
            continue;
          }
          if (p['qos'] is int) {
            qos = p['qos'];
          }
        }
        Path path = Path.getValidNodePath(pathstr);

        if (path != null && path.isAbsolute) {
          _getNode(path, (LocalNode node) {
            _subscription.add(path.path, node, sid, qos);
            closeResponse(m['rid']);
          }, (e, stack) {
            var error = new DSError(
              "nodeError",
              msg: e.toString(),
              detail: stack.toString()
            );
            closeResponse(m['rid'], error: error);
          });
        } else {
          closeResponse(m['rid']);
        }
      }
    } else {
      closeResponse(m['rid'], error: DSError.INVALID_PATHS);
    }
  }

  void _getNode(Path p, Taker<LocalNode> func, [TwoTaker<dynamic, dynamic> onError]) {
    try {
      LocalNode node = nodeProvider.getOrCreateNode(p.path, false);

      if (node is WaitForMe) {
        (node as WaitForMe).onLoaded.then((n) {
          if (n is LocalNode) {
            node = n;
          }
          func(node);
        }).catchError((e, stack) {
          if (onError != null) {
            onError(e, stack);
          }
        });
      } else {
        func(node);
      }
    } catch (e, stack) {
      if (onError != null) {
        onError(e, stack);
      } else {
        rethrow;
      }
    }
  }

  void unsubscribe(Map m) {
    if (m['sids'] is List) {
      for (Object sid in m['sids']) {
        if (sid is int) {
          _subscription.remove(sid);
        }
      }
      closeResponse(m['rid']);
    } else {
      closeResponse(m['rid'], error: DSError.INVALID_PATHS);
    }
  }

  void invoke(Map m) {
    Path path = Path.getValidNodePath(m['path']);
    if (path != null && path.isAbsolute) {
      int rid = m['rid'];
      LocalNode parentNode;

      parentNode = nodeProvider.getOrCreateNode(path.parentPath, false);

      doInvoke([LocalNode overriden]) {
        LocalNode node = overriden == null ? nodeProvider.getNode(path.path) : overriden;
        if (node == null) {
          if (overriden == null) {
            node = parentNode.getChild(path.name);
            if (node == null) {
              closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
              return;
            }

            if (node is WaitForMe) {
              (node as WaitForMe).onLoaded.then((_) => doInvoke(node));
              return;
            } else {
              doInvoke(node);
              return;
            }
          } else {
            closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
            return;
          }
        }
        int permission = nodeProvider.permissions.getPermission(path.path, this);
        int maxPermit = Permission.parse(m['permit']);
        if (maxPermit < permission) {
          permission = maxPermit;
        }

        if (node.getInvokePermission() <= permission) {
          node.invoke(m['params'], this,
              addResponse(new InvokeResponse(this, rid, parentNode, node, path.name)), parentNode,
              permission);
        } else {
          closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
        }
      }

      if (parentNode is WaitForMe) {
        (parentNode as WaitForMe).onLoaded.then((_) {
          doInvoke();
        }).catchError((e, stack) {
          var err = new DSError(
            "nodeError",
            msg: e.toString(),
            detail: stack.toString()
          );
          closeResponse(
            m['rid'],
            error: err
          );
        });
      } else {
        doInvoke();
      }
    } else {
      closeResponse(m['rid'], error: DSError.INVALID_PATH);
    }
  }

  void updateInvoke(Map m) {
    int rid = m['rid'];
    if (_responses[rid] is InvokeResponse) {
      if ( m['params'] is Map) {
        (_responses[rid] as InvokeResponse).updateReqParams(m['params']);
      }
    } else {
      closeResponse(m['rid'], error: DSError.INVALID_METHOD);
    }
  }

  void set(Map m) {
    Path path = Path.getValidPath(m['path']);
    if (path == null || !path.isAbsolute) {
      closeResponse(m['rid'], error: DSError.INVALID_PATH);
      return;
    }

    if (!m.containsKey('value')) {
      closeResponse(m['rid'], error: DSError.INVALID_VALUE);
      return;
    }

    Object value = m['value'];
    int rid = m['rid'];
    if (path.isNode) {
      _getNode(path, (LocalNode node) {
        int permission = nodeProvider.permissions.getPermission(node.path, this);
        int maxPermit = Permission.parse(m['permit']);
        if (maxPermit < permission) {
          permission = maxPermit;
        }

        if (node.getSetPermission() <= permission) {
          node.setValue(value, this, addResponse(new Response(this, rid)));
        } else {
          closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
        }
        closeResponse(m['rid']);
      }, (e, stack) {
        var error = new DSError(
          "nodeError",
          msg: e.toString(),
          detail: stack.toString()
        );
        closeResponse(m['rid'], error: error);
      });
    } else if (path.isConfig) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);

      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.CONFIG) {
        closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
      } else {
        node.setConfig(
            path.name, value, this, addResponse(new Response(this, rid)));
      }
    } else if (path.isAttribute) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);
      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.WRITE) {
        closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
      } else {
        node.setAttribute(
            path.name, value, this, addResponse(new Response(this, rid)));
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void remove(Map m) {
    Path path = Path.getValidPath(m['path']);
    if (path == null || !path.isAbsolute) {
      closeResponse(m['rid'], error: DSError.INVALID_PATH);
      return;
    }
    int rid = m['rid'];
    if (path.isNode) {
      closeResponse(m['rid'], error: DSError.INVALID_METHOD);
    } else if (path.isConfig) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);

      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.CONFIG) {
        closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
      } else {
        node.removeConfig(
            path.name, this, addResponse(new Response(this, rid)));
      }
    } else if (path.isAttribute) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);
      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.WRITE) {
        closeResponse(m['rid'], error: DSError.PERMISSION_DENIED);
      } else {
        node.removeAttribute(
            path.name, this, addResponse(new Response(this, rid)));
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void close(Map m) {
    if (m['rid'] is int) {
      int rid = m['rid'];
      if (_responses.containsKey(rid)) {
        _responses[rid]._close();
        Response resp = _responses.remove(rid);
        if (_traceCallbacks != null) {
          traceResponseRemoved(resp);
        }
      }
    }
  }

  void onDisconnected() {
    clearProcessors();
    _responses.forEach((id, resp) {
      resp._close();
    });
    _responses.clear();
    _responses[0] = _subscription;
  }

  void onReconnected() {
    super.onReconnected();
  }

  List<ResponseTraceCallback> _traceCallbacks;

  void addTraceCallback(ResponseTraceCallback _traceCallback) {
    _subscription.addTraceCallback(_traceCallback);
    _responses.forEach((int rid, Response response){
      _traceCallback(response.getTraceData());
    });

    if (_traceCallbacks == null)
      _traceCallbacks = new LeakProofList<ResponseTraceCallback>.create(
        "responder trace callbacks"
      );

    _traceCallbacks.add(_traceCallback);
  }

  void removeTraceCallback(ResponseTraceCallback _traceCallback) {
    _traceCallbacks.remove(_traceCallback);
    if (_traceCallbacks.isEmpty) {
      _traceCallbacks = null;
    }
  }
}

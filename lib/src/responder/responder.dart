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
//    if (storage != null && nodes != null) {
//      for (ISubscriptionNodeStorage node in nodes) {
//        var values = node.getLoadedValues();
//        LocalNode localnode = nodeProvider.getOrCreateNode(node.path, false);
//        RespSubscribeController controller = _subscription.add(
//          node.path,
//          localnode,
//          -1,
//          node.qos
//        );
//
//        if (values.isNotEmpty) {
//          controller.resetCache(values);
//        }
//      }
//    }
  }

  /// list of permission group
  List<String> groups = [];
  void updateGroups(List<String> vals, [bool ignoreId = false]) {
    if (ignoreId) {
      groups = vals.where((str)=>str != '').toList();
    } else {
      groups = [reqId]..addAll(vals.where((str)=>str != ''));
    }
  }

  final Map<int, Response> _responses = new Map<int, Response>();

  int get openResponseCount {
    return _responses.length;
  }
//
//  int get subscriptionCount {
//    return _subscription.subscriptions.length;
//  }

  /// caching of nodes
  final NodeProvider nodeProvider;

  Responder(this.nodeProvider, [this.reqId]) {
    // TODO: load reqId
    if (reqId != null) {
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

  bool disabled = false;

  void onData(DSPacket pkt) {
    if (disabled){
      return;
    }

    if (pkt is DSRequestPacket) {
      _onReceiveRequest(pkt);
    }
  }

  void _onReceiveRequest(DSRequestPacket pkt) {
    DSPacketMethod method = pkt.method;

    if (pkt.method is DSPacketMethod) {
      if (method == null) {
        updateInvoke(pkt);
        return;
      } else {
        if (_responses.containsKey(pkt.rid)) {
          if (method == DSPacketMethod.close) {
            close(pkt);
            return;
          }
        }

        switch (method) {
          case DSPacketMethod.list:
            list(pkt);
            return;
          case DSPacketMethod.subscribe:
            subscribe(pkt);
            return;
          case DSPacketMethod.invoke:
            invoke(pkt);
            return;
          case DSPacketMethod.set:
            set(pkt);
            return;
          case DSPacketMethod.remove:
            remove(pkt);
            return;
        }
      }
    }
    closeResponse(pkt.rid, error: DSError.INVALID_METHOD);
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
    DSResponsePacket pkt = new DSResponsePacket();
    pkt.method = DSPacketMethod.close;
    pkt.rid = rid;
    pkt.mode = DSPacketResponseMode.closed;
    if (error != null) {
      pkt.setPayload(error.serialize());
    }
    _responses.remove(rid);
    addToSendList(pkt);
  }

  void updateResponse(Response response, List updates,
      {
        String streamStatus,
        List<dynamic> columns,
        Map meta,
        void handleMap(Map m)}) {
    if (_responses[response.rid] == response) {
      var pkt = new DSResponsePacket();
      pkt.method = response.method;
      pkt.rid = response.rid;
      pkt.updateId = response.getUpdateId();

      if (streamStatus != null && streamStatus != response._sentStreamStatus) {
        response._sentStreamStatus = streamStatus;
        pkt.mode = DSPacketResponseMode.encode(streamStatus);
      }

      if (response.method == DSPacketMethod.list) {
        pkt.setPayload(updates);
      } else if (response.method == DSPacketMethod.subscribe) {
        if (updates.length == 1) {
          pkt.setPayload(updates[0]);
        } else {
          pkt.setPayload(updates);
        }
      } else {
        var m = {};

        if (columns != null) {
          m['columns'] = columns;
        }

        if (updates != null) {
          m['rows'] = updates;
        }

        if (meta != null) {
          if (meta['mode'] is String) {
            m['mode'] = meta['mode'];
          }
        }

        if (handleMap != null) {
          handleMap(m);
        }

        pkt.setPayload(m);
      }

      addToSendList(pkt);
      if (response._sentStreamStatus == StreamStatus.closed) {
        _responses.remove(response.rid);
        if (_traceCallbacks != null) {
          traceResponseRemoved(response);
        }
      }
    }
  }

  void list(DSRequestPacket pkt) {
    Path path = Path.getValidNodePath(pkt.path);
    if (path != null && path.isAbsolute) {
      int rid = pkt.rid;

      _getNode(path, (LocalNode node) {
        addResponse(new ListResponse(this, rid, node));
      }, (e, stack) {
        var error = new DSError(
          "nodeError",
          msg: e.toString(),
          detail: stack.toString()
        );
        closeResponse(pkt.rid, error: error);
      });
    } else {
      closeResponse(pkt.rid, error: DSError.INVALID_PATH);
    }
  }

  void subscribe(DSRequestPacket pkt) {
    String pathString = pkt.path;
    int qos = pkt.qos;

    Path path = Path.getValidNodePath(pathString);

    if (path != null && path.isAbsolute) {
      _getNode(path, (LocalNode node) {
        _responses[pkt.rid] = new SubscribeResponse(
          this,
          pkt.rid,
          path.path,
          node,
          qos
        );
      }, (e, stack) {
        var error = new DSError(
          "nodeError",
          msg: e.toString(),
          detail: stack.toString()
        );
        closeResponse(pkt.rid, error: error);
      });
    } else {
      closeResponse(pkt.rid);
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

  void invoke(DSRequestPacket pkt) {
    Path path = Path.getValidNodePath(pkt.path);
    if (path != null && path.isAbsolute) {
      int rid = pkt.rid;
      LocalNode parentNode;

      parentNode = nodeProvider.getOrCreateNode(path.parentPath, false);

      doInvoke([LocalNode overriden]) {
        LocalNode node = overriden == null ?
          nodeProvider.getNode(path.path) :
          overriden;
        if (node == null) {
          if (overriden == null) {
            node = parentNode.getChild(path.name);
            if (node == null) {
              closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
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
            closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
            return;
          }
        }
        int permission = nodeProvider.permissions.getPermission(path.path, this);
        int maxPermit = Permission.NEVER; // TODO: Figure out how to copy permit for packets.
        if (maxPermit < permission) {
          permission = maxPermit;
        }

        var pl = pkt.readPayloadPackage();

        Map<String, dynamic> params = pl["params"];

        if (params == null) {
          params = {};
        }

        if (node.getInvokePermission() <= permission) {
          node.invoke(
            params,
            this,
            addResponse(
              new InvokeResponse(this, rid, parentNode, node, path.name)
            ),
            parentNode,
            permission
          );
        } else {
          closeResponse(rid, error: DSError.PERMISSION_DENIED);
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
            pkt.rid,
            error: err
          );
        });
      } else {
        doInvoke();
      }
    } else {
      closeResponse(pkt.rid, error: DSError.INVALID_PATH);
    }
  }

  void updateInvoke(DSRequestPacket pkt) {
    int rid = pkt.rid;
    if (_responses[rid] is InvokeResponse) {
      var pl = pkt.readPayloadPackage();
      Map<String, dynamic> params = pl["params"];

      if (params is Map) {
        (_responses[rid] as InvokeResponse).updateReqParams(params);
      }
    } else {
      closeResponse(pkt.rid, error: DSError.INVALID_METHOD);
    }
  }

  void set(DSRequestPacket pkt) {
    Path path = Path.getValidPath(pkt);
    if (path == null || !path.isAbsolute) {
      closeResponse(pkt.rid, error: DSError.INVALID_PATH);
      return;
    }

    Map m = pkt.readPayloadPackage();

    if (!m.containsKey('value')) {
      closeResponse(pkt.rid, error: DSError.INVALID_VALUE);
      return;
    }

    Object value = m["value"];
    int rid = pkt.rid;

    if (path.isNode) {
      _getNode(path, (LocalNode node) {
        int permission = nodeProvider.permissions.getPermission(node.path, this);
        int maxPermit = Permission.parse(m['permit']);
        if (maxPermit < permission) {
          permission = maxPermit;
        }

        if (node.getSetPermission() <= permission) {
          node.setValue(
            value,
            this,
            addResponse(new Response(pkt.method, this, rid))
          );
        } else {
          closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
        }
        closeResponse(pkt.rid);
      }, (e, stack) {
        var error = new DSError(
          "nodeError",
          msg: e.toString(),
          detail: stack.toString()
        );
        closeResponse(pkt.rid, error: error);
      });
    } else if (path.isConfig) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);

      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.CONFIG) {
        closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
      } else {
        node.setConfig(
            path.name, value, this, addResponse(new Response(pkt.method, this, rid)));
      }
    } else if (path.isAttribute) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);
      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.WRITE) {
        closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
      } else {
        node.setAttribute(
            path.name, value, this, addResponse(new Response(pkt.method, this, rid)));
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void remove(DSRequestPacket pkt) {
    Path path = Path.getValidPath(pkt.path);
    if (path == null || !path.isAbsolute) {
      closeResponse(pkt.rid, error: DSError.INVALID_PATH);
      return;
    }
    int rid = pkt.rid;
    if (path.isNode) {
      closeResponse(pkt.rid, error: DSError.INVALID_METHOD);
    } else if (path.isConfig) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);

      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.CONFIG) {
        closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
      } else {
        node.removeConfig(
          path.name,
          this,
          addResponse(new Response(pkt.method, this, rid))
        );
      }
    } else if (path.isAttribute) {
      LocalNode node;

      node = nodeProvider.getOrCreateNode(path.parentPath, false);
      int permission = nodeProvider.permissions.getPermission(node.path, this);
      if (permission < Permission.WRITE) {
        closeResponse(pkt.rid, error: DSError.PERMISSION_DENIED);
      } else {
        node.removeAttribute(
            path.name, this, addResponse(new Response(pkt.method, this, rid)));
      }
    } else {
      // shouldn't be possible to reach here
      throw 'unexpected case';
    }
  }

  void close(DSRequestPacket pkt) {
    if (pkt.rid is int) {
      int rid = pkt.rid;
      if (_responses.containsKey(rid)) {
        _responses[rid]._close();
        Response resp = _responses.remove(rid);

        if (resp is SubscribeResponse) {
          resp.remove();
        }

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
//    _responses[0] = _subscription;
  }

  void onReconnected() {
    super.onReconnected();
  }

  List<ResponseTraceCallback> _traceCallbacks;

  void addTraceCallback(ResponseTraceCallback _traceCallback) {
//    _subscription.addTraceCallback(_traceCallback);
    _responses.forEach((int rid, Response response){
      _traceCallback(response.getTraceData());
    });

    if (_traceCallbacks == null) _traceCallbacks = new List<ResponseTraceCallback>();

    _traceCallbacks.add(_traceCallback);
  }

  void removeTraceCallback(ResponseTraceCallback _traceCallback) {
    _traceCallbacks.remove(_traceCallback);
    if (_traceCallbacks.isEmpty) {
      _traceCallbacks = null;
    }
  }
}

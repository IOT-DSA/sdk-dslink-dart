part of dslink.responder;

class ListResponse extends Response {
  final LocalNode node;
  StreamSubscription _nodeChangeListener;
  int _permission;

  ListResponse(Responder responder, int rid, this.node)
      : super(responder, rid) {
    _permission =
        responder.nodeProvider.permissions.getPermission(node.path, responder);
    _nodeChangeListener = node.listStream.listen(changed);
    if (node.listReady) {
      prepareSending();
    } else if (node.disconnected != null) {
      prepareSending();
    }
  }

  LinkedHashSet<String> changes = new LinkedHashSet<String>();
  bool initialResponse = true;

  void changed(String key) {
    if (_permission == Permission.NONE) {
      return;
    }

    if (key.startsWith(r'$$')) {
      if (_permission < Permission.CONFIG) {
        return;
      }
      if (key.startsWith(r'$$$')) {
        return;
      }
    }

    if (changes.isEmpty) {
      changes.add(key);
      prepareSending();
    } else {
      changes.add(key);
    }
  }

  bool _disconnectSent = false;

  @override
  void startSendingData(int currentTime, int waitingAckId) {
    _pendingSending = false;

    if (waitingAckId != -1) {
      _waitingAckCount++;
      _lastWatingAckId = waitingAckId;
    }

    Object updateIs;
    Object updateBase;
    List updateConfigs = [];
    List updateAttributes = [];
    List updateChildren = [];

    if (node.disconnected != null) {
      responder.updateResponse(
          this,
          node.getDisconnectedListResponse(),
          streamStatus: StreamStatus.open);
      _disconnectSent = true;
      changes.clear();
      return;
    } else if (_disconnectSent && !changes.contains(r'$disconnectedTs')) {
      _disconnectSent = false;
      updateConfigs.add({'name': r'$disconnectedTs', 'change': 'remove'});
      if (node.configs.containsKey(r'$disconnectedTs')) {
        node.configs.remove(r'$disconnectedTs');
      }
    }

    // TODO: handle permission and permission change
    if (initialResponse || changes.contains(r'$is')) {
      initialResponse = false;
      if (_permission == Permission.NONE) {
        return;
      } else {
        node.configs.forEach((name, value) {
          Object update = [name, value];
          if (name == r'$is') {
            updateIs = update;
          } else if (name == r'$base') {
            updateBase = update;
          } else if (name.startsWith(r'$$')) {
            if (_permission == Permission.CONFIG && !name.startsWith(r'$$$')) {
              updateConfigs.add(update);
            }
          } else {
            if (_permission != Permission.CONFIG) {
              if (name == r'$writable') {
                if (_permission < Permission.WRITE) {
                  return;
                }
              }
              if (name == r'$invokable') {
                int invokePermission = Permission.parse(node.getConfig(r'$invokable'));
                if (invokePermission > _permission) {
                  updateConfigs.add([r'$invokable', 'never']);
                  return;
                }
              } 
            }
            updateConfigs.add(update);
          }
        });
        node.attributes.forEach((name, value) {
          updateAttributes.add([name, value]);
        });
        node.children.forEach((name, Node value) {
          Map simpleMap = value.getSimpleMap();
          if (_permission != Permission.CONFIG) {
            int invokePermission = Permission.parse(simpleMap[r'$invokable']);
            if (invokePermission != Permission.NEVER && invokePermission > _permission) {
              simpleMap[r'$invokable'] = 'never';
            }
          }
          updateChildren.add([name, simpleMap]);
        });
      }
      if (updateIs == null) {
        updateIs = [r'$is', 'node'];
      }
    } else {
      for (String change in changes) {
        Object update;
        if (change.startsWith(r'$')) {
          if (_permission != Permission.CONFIG) {
            if (change == r'$writable') {
              if (_permission < Permission.WRITE) {
                continue;
              }
            }
            if (change == r'$invokable') {
              int invokePermission = Permission.parse(node.getConfig(r'$invokable'));
              if (invokePermission > _permission) {
                updateConfigs.add([r'$invokable', 'never']);
                continue;
              }
            } 
          }
          if (node.configs.containsKey(change)) {
            update = [change, node.configs[change]];
          } else {
            update = {'name': change, 'change': 'remove'};
          }
          if (_permission == Permission.CONFIG || !change.startsWith(r'$$')) {
            updateConfigs.add(update);
          }
        } else if (change.startsWith(r'@')) {
          if (node.attributes.containsKey(change)) {
            update = [change, node.attributes[change]];
          } else {
            update = {'name': change, 'change': 'remove'};
          }
          updateAttributes.add(update);
        } else {
          if (node.children.containsKey(change)) {
            Map simpleMap = node.children[change].getSimpleMap();
             if (_permission != Permission.CONFIG) {
               int invokePermission = Permission.parse(simpleMap[r'$invokable']);
               if (invokePermission != Permission.NEVER && invokePermission > _permission) {
                 simpleMap[r'$invokable'] = 'never';
               }
             }
            update = [change, simpleMap ];
          } else {
            update = {'name': change, 'change': 'remove'};
          }
          updateChildren.add(update);
        }
      }
    }

    changes.clear();

    List updates = [];
    if (updateBase != null) {
      updates.add(updateBase);
    }
    if (updateIs != null) {
      updates.add(updateIs);
    }
    updates..addAll(updateConfigs)..addAll(updateAttributes)..addAll(
        updateChildren);

    responder.updateResponse(this, updates, streamStatus: StreamStatus.open);
  }

  int _waitingAckCount = 0;
  int _lastWatingAckId = -1;

  void ackReceived(int receiveAckId, int startTime, int currentTime) {
    if (receiveAckId == _lastWatingAckId) {
      _waitingAckCount = 0;
    } else {
      _waitingAckCount--;
    }

    if (_sendingAfterAck) {
      _sendingAfterAck = false;
      prepareSending();
    }
  }

  bool _sendingAfterAck = false;

  void prepareSending() {
    if (_sendingAfterAck) {
      return;
    }
    if (_waitingAckCount > ConnectionProcessor.ACK_WAIT_COUNT) {
      _sendingAfterAck = true;
      return;
    }
    if (!_pendingSending) {
      _pendingSending = true;
      responder.addProcessor(this);
    }
  }

  void _close() {
    _nodeChangeListener.cancel();
  }

  /// for the broker trace action
  ResponseTrace getTraceData([String change = '+']) {
    return new ResponseTrace(node.path, 'list', rid, change, null);
  }
}

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
      responder.addProcessor(processor);
    } else if (node.disconnected != null) {
      responder.addProcessor(processor);
    }
  }

  LinkedHashSet<String> changes = new LinkedHashSet<String>();
  bool initialResponse = true;
  void changed(String key) {
    if (_permission == Permission.NONE) {
      return;
    }
    if (_permission < Permission.CONFIG && key.startsWith(r'$$')) {
      return;
    }
    if (changes.isEmpty) {
      changes.add(key);
      responder.addProcessor(processor);
    } else {
      changes.add(key);
    }
  }

  bool _disconnectSent = false;
  void processor() {
    Object updateIs;
    Object updateBase;
    List updateConfigs = [];
    List updateAttributes = [];
    List updateChildren = [];

    if (node.disconnected != null) {
      responder.updateResponse(
          this,
          [
            [r'$disconnectedTs', node.disconnected]
          ],
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
    // TODO handle permission and permission change

    if (initialResponse || changes.contains(r'$is')) {
      initialResponse = false;
      node.configs.forEach((name, value) {
        Object update = [name, value];
        if (name == r'$is') {
          updateIs = update;
        } else if (name == r'$base') {
          updateBase = update;
        } else if (_permission == Permission.CONFIG ||
            !name.startsWith(r'$$')) {
          updateConfigs.add(update);
        }
      });
      node.attributes.forEach((name, value) {
        updateAttributes.add([name, value]);
      });
      node.children.forEach((name, LocalNode value) {
        print('$name $value');
        updateChildren.add([name, value.getSimpleMap()]);
      });
      if (updateIs == null) {
        updateIs = 'node';
      }
    } else {
      for (String change in changes) {
        Object update;
        if (change.startsWith(r'$')) {
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
            update = [change, node.children[change].getSimpleMap()];
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
    updates
      ..addAll(updateConfigs)
      ..addAll(updateAttributes)
      ..addAll(updateChildren);

    responder.updateResponse(this, updates, streamStatus: StreamStatus.open);
  }

  void _close() {
    _nodeChangeListener.cancel();
  }
}

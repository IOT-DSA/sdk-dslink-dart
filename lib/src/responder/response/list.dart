part of dslink.responder;

class ListResponse extends Response {
  final LocalNode node;
  StreamSubscription _nodeChangeListener;
  ListResponse(Responder responder, int rid, this.node) : super(responder, rid) {
    _nodeChangeListener = node.listStream.listen(changed);
    if (node.listReady) {
      responder.addProcessor(processor);
    }
  }

  LinkedHashSet<String> changes = new LinkedHashSet<String>();
  bool initialResponse = true;
  void changed(String key) {
    if (changes.isEmpty) {
      changes.add(key);
      responder.addProcessor(processor);
    } else {
      changes.add(key);
    }
  }
  void processor() {
    // TODO handle permission and permission change
    Object updateIs;
    Object updateMixin;
    List updateConfigs = [];
    List updateAttributes = [];
    List updateChildren = [];
    if (initialResponse || changes.contains(r'$is')) {
      initialResponse = false;
      node.configs.forEach((name, value) {
        Object update = [name, value];
        if (name == r'$is') {
          updateIs = update;
        } else if (name == r'$mixin') {
          updateMixin = update;
        } else {
          updateConfigs.add(update);
        }
      });
      node.attributes.forEach((name, value) {
        updateAttributes.add([name, value]);
      });
      node.children.forEach((name, LocalNode value) {
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
            update = {
              'name': change,
              'change': 'remove'
            };
          }
          if (change == r'$mixin') {
            updateMixin = update;
          } else {
            updateConfigs.add(update);
          }
        } else if (change.startsWith(r'a')) {
          if (node.attributes.containsKey(change)) {
            update = [change, node.attributes[change]];
          } else {
            update = {
              'name': change,
              'change': 'remove'
            };
          }
          updateAttributes.add(update);
        } else {
          if (node.children.containsKey(change)) {
            update = [change, node.children[change].getSimpleMap()];
          } else {
            update = {
              'name': change,
              'change': 'remove'
            };
          }
          updateChildren.add(update);
        }
      }
    }
    changes.clear();

    List updates = [];
    if (updateIs != null) {
      updates.add(updateIs);
    }
    if (updateMixin != null) {
      updates.add(updateMixin);
    }
    updates
        ..addAll(updateConfigs)
        ..addAll(updateAttributes)
        ..addAll(updateChildren);

    responder.updateReponse(this, updates, streamStatus: StreamStatus.open);
  }
  void _close() {
    _nodeChangeListener.cancel();
  }
}

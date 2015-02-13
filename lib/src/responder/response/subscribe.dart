part of dslink.responder;

class SubscribeResponse extends Response {
  SubscribeResponse(Responder responder, int rid) : super(responder, rid);

  final Map<String, RespSubscribeController> subsriptions = new Map<String, RespSubscribeController>();

  final LinkedHashSet<RespSubscribeController> changed = new LinkedHashSet<RespSubscribeController>();

  void add(String path, RespSubscribeController controller) {
    if (subsriptions[path] != null) {
      subsriptions[path].destroy();
    }
    subsriptions[path] = controller;
  }
  void remove(String path) {
    if (subsriptions[path] != null) {
      subsriptions[path].destroy();
    }
  }

  void subscriptionChanged(RespSubscribeController controller) {
    changed.add(controller);
    responder.addProcessor(processor);
  }
  void processor() {
    List updates = [];
    for (RespSubscribeController controller in changed) {
      updates.add(controller.process());
    }
    responder.updateReponse(this, updates);
    changed.clear();
  }
  void _close() {
    subsriptions.forEach((path, controller) {
      controller.destroy();
    });
    subsriptions.clear();
  }
}

class RespSubscribeController {
  final LocalNode node;
  final SubscribeResponse response;
  StreamSubscription _listener;
  RespSubscribeController(this.response, this.node) {
    addValue(node.lastValueUpdate);
    _listener = node.valueStream.listen(addValue);
  }

  ValueUpdate lastValue;
  void addValue(ValueUpdate val) {
    if (lastValue == null) {
      if (val == null){
        int debuga = 1;
      }
      lastValue = val;
    } else {
      lastValue = new ValueUpdate.merge(lastValue, val);
    }
    // TODO, don't allow this to be called from same controller more oftern than 100ms
    // the first response can happen ASAP, but
    response.subscriptionChanged(this);
  }

  Object process() {
    Object rslt;
    if (lastValue == null) {
      int debuga = 1;
    }
    if (lastValue.count > 1 || lastValue.status != null) {
      Map m = {
        'ts': lastValue.ts,
        'value': lastValue.value,
        'path': node.path
      };
      if (lastValue.count == 0) {} else if (lastValue.count > 1) {
        m['count'] = lastValue.count;
        if (lastValue.sum.isFinite) {
          m['sum'] = lastValue.sum;
        }
        if (lastValue.max.isFinite) {
          m['max'] = lastValue.max;
        }
        if (lastValue.min.isFinite) {
          m['min'] = lastValue.min;
        }
      }
      rslt = m;
    } else {
      rslt = [node.path, lastValue.value, lastValue.ts];
    }
    lastValue = null;
    return rslt;
  }
  void destroy() {
    _listener.cancel();
  }
}

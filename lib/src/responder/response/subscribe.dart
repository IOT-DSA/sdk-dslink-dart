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
  }
}

class RespSubscribeController {
  final ResponderNode node;
  final SubscribeResponse response;
  StreamSubscription _listener;
  RespSubscribeController(this.response, this.node) {
    _listener = node.valueStream.listen(addValue);
  }

  Object lastValue;
  String lastTs;
  int count = 0;
  String lastStatus;
  num sum = double.NAN;
  num min = double.NAN;
  num max = double.NAN;
  void addValue(ValueUpdate v) {
    Object value = v.value;
    // TODO: this is incorrect now, ignore the value, use the min max sum count in RespValue
    if (count > 0) {
      if (value is num && lastValue is num) {
        if (count == 1) {
          sum = lastValue;
          min = lastValue;
          max = lastValue;
        }
        sum += value;
        if (value < min) min = value;
        if (value > max) max = value;
      } else {
        sum = double.NAN;
        min = double.NAN;
        max = double.NAN;
      }
      ++count;

    } else {
      count = 1;
    }
    lastValue = value;
    lastTs = v.ts;
    lastStatus = v.status;
    // TODO, don't allow this to be called from same controller more oftern than 100ms
    // the first response can happen ASAP, but
    response.subscriptionChanged(this);
  }

  Object process() {
    Object rslt;
    if (count > 1 || lastStatus != null) {
      Map m = {
        'ts': lastTs,
        'value': lastValue,
        'path': node.path
      };
      if (count > 1) {
        m['count'] = count;
        if (sum == sum) {
          m['sum'] = sum;
        }
        if (max == max) {
          m['max'] = max;
        }
        if (min == min) {
          m['min'] = min;
        }
      }
      rslt = m;
    } else {
      rslt = [node.path, lastValue, lastTs];
    }
    count = 0;
    sum = double.NAN;
    min = double.NAN;
    max = double.NAN;
    return rslt;
  }
  void destroy() {
    _listener.cancel();
  }
}

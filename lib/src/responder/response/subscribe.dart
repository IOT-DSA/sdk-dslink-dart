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
  final ValueController valueController;
  StreamSubscription _listener;
  RespSubscribeController(this.response, this.node, this.valueController) {
    _listener = valueController.stream.listen(addValue);
  }

  Object lastValue;
  String lastTs;
  int count = 0;
  String lastStatus;
  num sum = double.NAN;
  num min = double.NAN;
  num max = double.NAN;
  void addValue(RespValue v) {
    Object value = v.value;
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

class RespValue {
  Object value;
  String ts;
  String status;
  RespValue(this.value, this.ts, [this.status]);
}
class ValueController {
  final StreamController<RespValue> controller = new StreamController<RespValue>();
  Stream<RespValue> get stream => controller.stream;
}

part of dslink.broker;

class BrokerTraceNode extends BrokerHiddenNode {
  static BrokerTraceNode traceNode;
  static void init(BrokerNodeProvider broker) {
    if (traceNode == null) {
      traceNode = new BrokerTraceNode(broker);
      broker.setNode('/sys/trace', traceNode);
      broker.setNode('/sys/trace/traceRequester', traceNode.traceRequester);
      broker.setNode('/sys/trace/traceConnection', traceNode.traceConnection);
    }
  }

  BrokerTraceNode(BrokerNodeProvider provider) : super('/sys/trace', provider) {
    traceRequester = new BrokerTraceRequesterNode(provider);
    traceConnection = new BrokerTraceConnectionNode(provider);
    children['traceRequester'] = traceRequester;
    children['traceConnection'] = traceConnection;
  }

  BrokerTraceRequesterNode traceRequester;
  BrokerTraceConnectionNode traceConnection;
}

class _BrokerTraceResponderListener {
  final String path;
  final String sessionId;
  final BrokerTraceRequesterNode node;
  final Responder responder;

  _BrokerTraceResponderListener(
      this.path, this.sessionId, this.node, this.responder) {
    responder.addTraceCallback(onTrace);
    responses = [];
  }

  Map<String, ResponseTrace> cachedSubscription =
      new Map<String, ResponseTrace>();
  Map<int, ResponseTrace> cachedResponses = new Map<int, ResponseTrace>();

  List<InvokeResponse> responses;

  void destroy() {
    //TODO
    node._listeners.remove(path);
  }

  void onTrace(ResponseTrace update) {
    if (update == null) return;
    
    if (update.change == '+') {
      if (update.type == 'subscribe') {
        cachedSubscription[update.path] = update;
      } else {
        cachedResponses[update.rid] = update;
      }
    } else if (update.change == '-') {
      if (update.type == 'subscribe') {
        cachedSubscription.remove(update.path);
      } else {
        cachedResponses.remove(update.rid);
      }
    }
    if (responses != null) {
      for (InvokeResponse response in responses) {
        response.updateStream([update.rowData]);
      }
    }
  }
  void add(InvokeResponse response) {
    responses.add(response);
    response.onClose = remove;
    response.updateStream(cachedSubscription.values.map((trace)=>trace.rowData).toList());
    response.updateStream(cachedResponses.values.map((trace)=>trace.rowData).toList());
  }

  void remove(InvokeResponse response) {
    responses.remove(response);
    if (responses.isEmpty) {
      destroy();
    }
  }
}

class BrokerTraceRequesterNode extends BrokerNode {
  BrokerTraceRequesterNode(BrokerNodeProvider provider)
      : super('/sys/trace/traceRequester', provider) {
    configs[r'$invokable'] = 'config';
    configs[r'$result'] = 'stream';
    configs[r'$params'] = [
      {
        'name': 'requester',
        'type': 'string',
        'placeholder': 'full path to the requester dslink'
      },
      {'name': 'sessionId', 'type': 'string'}
    ];
    configs[r'$columns'] = [
      {'name': 'path', 'type': 'string'},
      {'name': 'type', 'type': 'string'},
      {'name': 'rid', 'type': 'number'},
      {'name': 'action', 'type': 'string'},
      {'name': 'change', 'type': 'string'},
    ];
  }

  Map<String, _BrokerTraceResponderListener> _listeners =
      new Map<String, _BrokerTraceResponderListener>();

  @override
  InvokeResponse invoke(Map params, Responder responder,
      InvokeResponse response, LocalNode parentNode,
      [int maxPermission = Permission.CONFIG]) {
    Object path = params['requester'];
    Object sessionId = params['sessionId'];
    if (sessionId == null) sessionId = '';
    Node node = provider.getOrCreateNode(path, false);
    if (path is String && sessionId is String && node is RemoteLinkRootNode) {
      if (node._linkManager.responders != null && node._linkManager.responders.containsKey(sessionId)) {
        if (!_listeners.containsKey(path)) {
          _listeners[path] = new _BrokerTraceResponderListener(
              path, sessionId, this, node._linkManager.responders[sessionId]);
        }
        _listeners[path].add(response);
        return response;
      }
    }
    return response..close(DSError.INVALID_PARAMETER);
  }
}
class BrokerTraceConnectionNode extends BrokerNode {
  BrokerTraceConnectionNode(BrokerNodeProvider provider)
      : super('/sys/trace/traceConnection', provider) {
    configs[r'$invokable'] = 'config';
  }
}

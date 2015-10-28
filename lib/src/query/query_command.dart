part of dslink.query;

abstract class BrokerQueryCommand {
  final BrokerQueryManager _manager;
  BrokerQueryCommand(this._manager) {}

  BrokerQueryCommand base;
  Set<BrokerQueryCommand> nexts = new Set<BrokerQueryCommand>();
  Set<InvokeResponse> responses = new Set<InvokeResponse>();

  void addResponse(InvokeResponse response) {
    response.onClose = _onResponseClose;
    responses.add(response);
  }

  void _onResponseClose(InvokeResponse response) {
    responses.remove(response);
    if (responses.isEmpty && nexts.isEmpty) {
      destroy();
    }
  }

  void addNext(BrokerQueryCommand next) {
    nexts.add(next);
  }

  void removeNext(BrokerQueryCommand next) {
    nexts.remove(next);
    if (nexts.isEmpty && responses.isEmpty) {
      destroy();
    }
  }

  /// init after checking command is not a duplication
  void init(){
    
  }
  
  void updateFromBase(List updats);

  void destroy() {
    for (InvokeResponse resp in responses) {
      resp.close;
    }
    if (base != null) {
      base.removeNext(this);
    }
    _manager._dict.remove(getQueryId());
  }

  
  String _cachedQueryId;

  /// return a unified String as the key of the map
  String getQueryId() {
    if (_cachedQueryId == null) {
      if (base != null) {
        _cachedQueryId = '$base|$this';
      } else {
        _cachedQueryId = toString();
      }
    }
    return _cachedQueryId;
  }
}

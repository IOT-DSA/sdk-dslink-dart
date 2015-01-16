part of dslink.requester;

/// request class handles raw response from responder
class Request {
  final DsRequester requester;
  final int rid;
  /// raw request callback
  final _RequestUpdater updater;
  bool _isClosed = false;
  bool get isClosed => _isClosed;

  Request(this.requester, this.rid, this.updater);

  String streamStatus = StreamStatus.initialize;

  void _update(Map m) {
    if (m['stream'] is String) {
      streamStatus = m['stream'];
    }
    List updates;
    List columns;
    if (m['updates'] is List) {
      updates = m['updates'];
    }
    if (m['columns'] is List) {
      columns = m['columns'];
    }
    // remove the request from global Map
    if (streamStatus == StreamStatus.closed) {
      requester._requests.remove(rid);
    }
    updater(streamStatus, updates, columns);
  }

  /// close the request from the client side
  void _close() {
    if (streamStatus != StreamStatus.closed) {
      streamStatus = StreamStatus.closed;
      updater(StreamStatus.closed, null, null);
    }
  }

  /// close the request from the client side
  void close() {
    // _close will also be called later from the requester;
    requester.closeRequest(this);
  }
}

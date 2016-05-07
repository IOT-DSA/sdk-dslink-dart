part of dslink.requester;

class RemoveController implements RequestUpdater {
  final Completer<RequesterUpdate> completer = new Completer<RequesterUpdate>();
  Future<RequesterUpdate> get future => completer.future;

  final Requester requester;
  final String path;
  Request _request;

  RemoveController(this.requester, this.path) {
    var reqMap = <String, dynamic>{
      'method': 'remove',
      'path': path
    };

    _request = requester._sendRequest(reqMap, this);
  }

  void onUpdate(String status, List updates, List columns, Map meta, DSError error) {
    // TODO implement error
    completer.complete(new RequesterUpdate(status));
  }

  void onDisconnect() {}

  void onReconnect() {}
}

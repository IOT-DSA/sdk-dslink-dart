part of dslink.requester;

class SetController implements RequestUpdater {
  final Completer<RequesterUpdate> completer = new Completer<RequesterUpdate>();
  Future<RequesterUpdate> get future => completer.future;
  final Requester requester;
  final String path;
  final Object value;
  Request _request;

  SetController(this.requester, this.path, this.value,
      [int maxPermission = Permission.CONFIG]) {
    Map reqMap = {'method': 'set', 'path': path, 'value': value};
    if (maxPermission != Permission.CONFIG) {
      reqMap['permit'] = Permission.names[maxPermission];
    }
    _request = requester._sendRequest(reqMap, this);
  }

  void onUpdate(String status, List updates, List columns, [DSError error]) {
    // TODO implement error
    completer.complete(new RequesterUpdate(status));
  }

  void onDisconnect() {}

  void onReconnect() {}
}

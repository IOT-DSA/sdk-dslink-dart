part of dslink.requester;

class SetController {
  final Completer<RequesterUpdate> completer = new Completer<RequesterUpdate>();
  Future<RequesterUpdate> get future => completer.future;
  final Requester requester;
  final String path;
  final Object value;
  Request _request;
  SetController(this.requester, this.path, this.value) {
    Map reqMap = {'method': 'set', 'path': path, 'value': value};
    _request = requester._sendRequest(reqMap, _onUpdate);
  }

  void _onUpdate(String status, List updates, List columns) {
    completer.complete(new RequesterUpdate(status));
  }
}

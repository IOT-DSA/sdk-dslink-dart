part of dslink.requester;

class RemoveController {
  final Completer<RequesterUpdate> completer = new Completer<RequesterUpdate>();
  Future<RequesterUpdate> get future => completer.future;
  final Requester requester;
  final String path;
  Request _request;
  RemoveController(this.requester, this.path){
    Map reqMap = {
      'method': 'remove',
      'path': path
    };
    _request = requester._sendRequest(reqMap, _onUpdate);
  }
  
  void _onUpdate(String status, List updates, List columns) {
    completer.complete(new RequesterUpdate());
  }
}
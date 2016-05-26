part of dslink.requester;

class RemoveController implements RequestUpdater {
  final Completer<RequesterUpdate> completer = new Completer<RequesterUpdate>();
  Future<RequesterUpdate> get future => completer.future;

  final Requester requester;
  final String path;
  Request _request;

  RemoveController(this.requester, this.path) {
    var pkt = new DSRequestPacket();
    pkt.method = DSPacketMethod.remove;
    pkt.path = path;
    _request = requester._sendRequest(pkt, this);
  }

  void onUpdate(String status, List updates, List columns, Map meta, DSError error) {
    // TODO implement error
    completer.complete(new RequesterUpdate(status));
  }

  void onDisconnect() {}

  void onReconnect() {}
}

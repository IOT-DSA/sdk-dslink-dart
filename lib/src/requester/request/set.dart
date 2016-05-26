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
    var pkt = new DSRequestPacket();
    pkt.method = DSPacketMethod.set;
    pkt.path = path;
    var m = {
      "value": value
    };

    if (maxPermission != Permission.CONFIG) {
      m["permit"] = Permission.names[maxPermission];
    }

    pkt.setPayload(m);
    requester.sendRequest(pkt, this);

    _request = requester._sendRequest(pkt, this);
  }

  void onUpdate(String status, List updates, List columns, Map meta, DSError error) {
    // TODO implement error
    completer.complete(new RequesterUpdate(status));
  }

  void onDisconnect() {}

  void onReconnect() {}
}

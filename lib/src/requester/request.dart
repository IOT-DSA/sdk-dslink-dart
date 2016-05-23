part of dslink.requester;

/// request class handles raw response from responder
class Request {
  final Requester requester;
  final int rid;
  final DSRequestPacket packet;

  /// raw request callback
  final RequestUpdater updater;
  bool _isClosed = false;
  bool get isClosed => _isClosed;

  int _updateId = 0;

  Request(this.requester, this.rid, this.updater, this.packet);

  String streamStatus = StreamStatus.initialize;

  /// resend the data if previous sending failed
  void resend() {
    requester.addToSendList(packet);
  }

  void addReqParams(Map m) {
    var pkt = new DSRequestPacket();
    pkt.rid = rid;
    pkt.updateId = _updateId++;
    pkt.setPayload({
      "params": m
    });
    requester.addToSendList(pkt);
  }

  void _update(DSResponsePacket pkt) {
    if (pkt.mode != null) {
      streamStatus = pkt.mode.name;
    }

    var m = pkt.readPayloadPackage();

    List updates;
    List columns;
    Map meta;

    if (pkt.method == DSPacketMethod.list) {
      updates = m;
    } else if (m is Map) {
      if (m["rows"] is List) {
        updates = m["rows"];
      }

      if (m["columns"] is List) {
        columns = m["columns"];
      }

      if (m["mode"] is String) {
        meta = {
          "mode": m["mode"]
        };
      }
    }

    // remove the request from global Map
    if (streamStatus == StreamStatus.closed) {
      requester._requests.remove(rid);
    }

    DSError error;

    if (pkt.method == DSPacketMethod.close) {
      if (m.containsKey("error") && m["error"] is Map) {
        error = new DSError.fromMap(m["error"]);
        requester._errorController.add(error);
      }
    }

    updater.onUpdate(streamStatus, updates, columns, meta, error);
  }

  /// close the request and finish data
  void _close([DSError error]) {
    if (streamStatus != StreamStatus.closed) {
      streamStatus = StreamStatus.closed;
      updater.onUpdate(StreamStatus.closed, null, null, null, error);
    }
  }

  /// close the request from the client side
  void close() {
    // _close will also be called later from the requester;
    requester.closeRequest(this);
  }
}

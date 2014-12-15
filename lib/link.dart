library dslink.link;

import "dart:async";
import "dart:io";

import "_link.dart";
export "_link.dart";

class _IOSide extends SideProvider {
  WebSocket _socket;
  
  @override
  Future connect(String url) {
    return WebSocket.connect(url).then((sock) {
      sock.pingInterval = new Duration(seconds: 5);
      sock.listen((data) {
        if (data is String) {
          if (link.debug) print("RECEIVED: ${data}");
          link.handleMessage(data);
        }
      });
    });
  }

  @override
  Future disconnect() {
    return _socket.close();
  }

  @override
  void send(String data) {
    _socket.add(data);
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {bool debug: false}) : super(name, new _IOSide(), debug: debug);
}

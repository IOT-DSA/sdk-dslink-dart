library dslink.link;

import "dart:async";
import "dart:io";

import "link_base.dart";
export "link_base.dart";

class _IOWebSocketProvider extends WebSocketProvider {
  _IOWebSocketProvider(String url) : super(url);
  
  WebSocket _socket;

  @override
  Future connect() {
    return WebSocket.connect(url).then((sock) {
      _socket = sock;
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

  @override
  Stream<String> stream() => _socket;
}

class _IOPlatformProvider extends PlatformProvider {
  @override
  WebSocketProvider createWebSocket(String url) {
    return new _IOWebSocketProvider(url);
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {bool debug: false}) : super(name, new _IOPlatformProvider(), debug: debug);
}

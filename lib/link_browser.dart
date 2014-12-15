library dslink.link;

import "dart:async";
import "dart:html";

import "_link.dart";
export "_link.dart";

class _BrowserSide extends SideProvider {
  WebSocket _socket;
  
  @override
  Future connect(String url) {
    _socket = new WebSocket(url);
    _socket.onMessage.listen((event) {
      var data = event.data;
      if (data is String) {
        if (link.debug) print("RECEIVED: ${data}");
        link.handleMessage(data);
      }
    });
    
    return _socket.onOpen.single;
  }

  @override
  Future disconnect() {
    _socket.close();
    return _socket.onClose.single;
  }

  @override
  void send(String data) {
    _socket.sendString(data);
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {bool debug: false}) : super(name, new _BrowserSide(), debug: debug);
}

library dslink.link;

import "dart:async";
import "dart:html";

import "_link.dart";
export "_link.dart";

class _BrowserSide extends SideProvider {
  WebSocket _socket;
  
  @override
  Future connect(String url) {
    var openCompleter = new Completer();
    
    _socket = new WebSocket(url);
    
    _socket.onOpen.listen((_) {
      openCompleter.complete();
    });
    
    _socket.onMessage.listen((event) {
      var data = event.data;
      if (link.debug) print("RECEIVED: ${data}");
      link.handleMessage(data);
    });
    
    return openCompleter.future;
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

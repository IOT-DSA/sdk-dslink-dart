library dslink.link;

import "dart:async";
import "dart:html";

import "link_base.dart";
export "link_base.dart";

class _BrowserWebSocketProvider extends WebSocketProvider {
  _BrowserWebSocketProvider(String url) : super(url);
  
  WebSocket _socket;

  @override
  Future connect() {
    var openCompleter = new Completer();
    
    _socket = new WebSocket(url);
    
    _socket.onOpen.listen((_) {
      openCompleter.complete();
    });
    
    return openCompleter.future;
  }

  @override
  Future disconnect() {
    _socket.close();
  
    var closeCompleter = new Completer();
    _socket.onClose.listen((_) {
      closeCompleter.complete();
    });
    
    return closeCompleter.future;
  }

  @override
  void send(String data) {
    _socket.sendString(data);
  }

  @override
  Stream<String> stream() => _socket.onMessage.map((event) => event.data);
}

class _BrowserPlatformProvider extends PlatformProvider {
  @override
  WebSocketProvider createWebSocket(String url) {
    return new _BrowserWebSocketProvider(url);
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {bool debug: false}) : super(name, new _BrowserPlatformProvider(), debug: debug);
}

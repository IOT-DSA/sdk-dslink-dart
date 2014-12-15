library dslink.platform;

import "dart:async";

abstract class PlatformProvider {
  WebSocketProvider createWebSocket(String url);
}

abstract class WebSocketProvider {
  final String url;
  
  WebSocketProvider(this.url);
  
  void send(String data);
  Stream<String> stream();
  Future connect();
  Future disconnect();
}
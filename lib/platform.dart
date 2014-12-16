library dslink.platform;

import "dart:async";

abstract class PlatformProvider {
  WebSocketProvider createWebSocket(String url);
  HttpProvider createHttpClient();
}

abstract class WebSocketProvider {
  final String url;
  
  WebSocketProvider(this.url);
  
  void send(String data);
  Stream<String> stream();
  Future connect();
  Future disconnect();
}

abstract class HttpProvider {
  Future<HttpResponse> send(HttpRequest request);
}

class HttpRequest {
  final String url;
  final String method;
  final String body;
  final Map<String, String> headers;
  
  HttpRequest(this.url, {this.method: "GET", this.body, this.headers: const {}});
}

class HttpResponse {
  final int statusCode;
  final String data;
  final Map<String, String> headers;
  
  HttpResponse(this.statusCode, this.data, this.headers);
}
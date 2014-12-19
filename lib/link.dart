library dslink.link;

import "dart:async";
import "dart:convert";
import "dart:io" as IO;

import "link_base.dart";
export "link_base.dart";

class _IOWebSocketProvider extends WebSocketProvider {
  _IOWebSocketProvider(String url) : super(url);
  
  IO.WebSocket _socket;

  @override
  Future connect() {
    return IO.WebSocket.connect(url).then((sock) {
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

  @override
  HttpProvider createHttpClient() {
    return new _IOHttpProvider();
  }
}

class _IOHttpProvider extends HttpProvider {
  @override
  Future<HttpResponse> send(HttpRequest request) {
    var client = new IO.HttpClient();
    return client.openUrl(request.method, Uri.parse(request.url)).then((req) {
      for (var key in request.headers.keys) {
        req.headers.set(key, request.headers[key]);
      }
      
      if (request.body != null) {
        req.write(request.body);
      }
      
      return req.close();
    }).then((response) {
      var map = {};
      response.headers.forEach((key, values) {
        map[key] = response.headers.value(key);
      });
      return response.transform(UTF8.decoder).join().then((value) {
        new Future(() {
          client.close();
        });
        return new HttpResponse(response.statusCode, value, map);
      });
    });
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {String host, bool debug: false}) : super(name, new _IOPlatformProvider(), host: host, debug: debug);
}

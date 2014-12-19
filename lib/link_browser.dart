library dslink.link;

import "dart:async";
import "dart:html" as HTML;

import "link_base.dart";
export "link_base.dart";

class _BrowserWebSocketProvider extends WebSocketProvider {
  _BrowserWebSocketProvider(String url) : super(url);
  
  HTML.WebSocket _socket;

  @override
  Future connect() {
    var openCompleter = new Completer();
    
    _socket = new HTML.WebSocket(url);
    
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

  @override
  HttpProvider createHttpClient() {
    return new _BrowserHttpProvider();
  }
}

class _BrowserHttpProvider extends HttpProvider {
  
  @override
  Future<HttpResponse> send(HttpRequest request) {
    var completer = new Completer();
    var req = new HTML.HttpRequest();
    req.open(request.method, request.url);
    for (var key in request.headers.keys) {
      req.setRequestHeader(key, request.headers[key]);
    }
    if (request.body != null) {
      req.send(request.body);
    }
    req.onReadyStateChange.listen((e) {
      if (req.readyState == HTML.HttpRequest.DONE) {
        var res = new HttpResponse(req.status, req.responseText, req.responseHeaders);
        completer.complete(res);
      }
    });
    return completer.future;
  }
}

class DSLink extends DSLinkBase {
  DSLink(String name, {String host, bool debug: false}) : super(name, new _BrowserPlatformProvider(), host: host, debug: debug);
}

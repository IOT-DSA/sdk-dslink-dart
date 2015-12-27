/// DSLink SDK IO Utilities
library dslink.io;

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";
import "dart:math";

import "package:crypto/crypto.dart";

/// Read raw text from stdin.
Stream<String> readStdinText() => stdin.transform(const Utf8Decoder());

/// Read each line from stdin.
Stream<String> readStdinLines() =>
    readStdinText().transform(const LineSplitter());

/// Helpers for working with HTTP
class HttpHelper {
  /// Main HTTP Client
  static HttpClient client = new HttpClient();

  /// Creates an [HttpClientRequest] with the given parameters.
  /// [method] is the HTTP method.
  /// [url] is the URL to make the request to.
  /// [headers] specifies additional headers to set.
  static Future<HttpClientRequest> createRequest(String method, String url, {Map<String, String> headers}) async {
    var request = await client.openUrl(method, Uri.parse(url));
    if (headers != null) {
      headers.forEach(request.headers.set);
    }
    return request;
  }

  /// Reads the entire [response] as a list of bytes.
  static Future<List<int>> readBytesFromResponse(HttpClientResponse response) async {
    return await response.fold([], (a, b) {
      a.addAll(b);
      return a;
    });
  }

  /// Fetches the specified [url] from HTTP.
  /// If [headers] is specified, the headers will be added onto the request.
  static Future<String> fetchUrl(String url, {Map<String, String> headers}) async {
    var request = await createRequest("GET", url, headers: headers);
    var response = await request.close();
    return const Utf8Decoder().convert(await readBytesFromResponse(response));
  }

  /// Fetches the specified [url] from HTTP as JSON.
  /// If [headers] is specified, the headers will be added onto the request.
  static Future<dynamic> fetchJSON(String url, {Map<String, String> headers}) async {
    return const JsonDecoder().convert(await fetchUrl(url, headers: headers));
  }

  static const String _webSocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

  static const bool enableStandardWebSocket =
    const bool.fromEnvironment("calzone.build", defaultValue: false) ||
      const bool.fromEnvironment("websocket.standard", defaultValue: false);

  /// Custom WebSocket Connection logic.
  static Future<WebSocket> connectToWebSocket(
      String url, {Iterable<String> protocols, Map<String, dynamic> headers, HttpClient httpClient}) async {
    Uri uri = Uri.parse(url);

    if (enableStandardWebSocket) {
      return await WebSocket.connect(url, protocols: protocols, headers: headers);
    }

    if (uri.scheme != "ws" && uri.scheme != "wss") {
      throw new WebSocketException("Unsupported URL scheme '${uri.scheme}'");
    }

    Random random = new Random();
    // Generate 16 random bytes.
    Uint8List nonceData = new Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonceData[i] = random.nextInt(256);
    }
    String nonce = CryptoUtils.bytesToBase64(nonceData);

    int port = uri.port;
    if (port == 0) {
      port = uri.scheme == "wss" ? 443 : 80;
    }

    uri = new Uri(
        scheme: uri.scheme == "wss" ? "https" : "http",
        userInfo: uri.userInfo,
        host: uri.host,
        port: port,
        path: uri.path,
        query: uri.query
    );

    HttpClient _client = httpClient == null ? (new HttpClient()
        ..badCertificateCallback = (a, b, c) => true) : httpClient;

    return _client.openUrl("GET", uri).then((HttpClientRequest request) {
      if (uri.userInfo != null && !uri.userInfo.isEmpty) {
        // If the URL contains user information use that for basic
        // authorization.
        String auth = CryptoUtils.bytesToBase64(UTF8.encode(uri.userInfo));
        request.headers.set(HttpHeaders.AUTHORIZATION, "Basic $auth");
      }
      if (headers != null) {
        headers.forEach((field, value) => request.headers.add(field, value));
      }
      // Setup the initial handshake.
      request.headers
        ..set(HttpHeaders.CONNECTION, "Upgrade")
        ..set(HttpHeaders.UPGRADE, "websocket")
        ..set("Sec-WebSocket-Key", nonce)
        ..set("Cache-Control", "no-cache")
        ..set("Sec-WebSocket-Version", "13");
      if (protocols != null) {
        request.headers.add("Sec-WebSocket-Protocol", protocols.toList());
      }
      return request.close();
    }).then((response) {
      void error(String message) {
        // Flush data.
        response.detachSocket().then((socket) {
          socket.destroy();
        });
        throw new WebSocketException(message);
      }
      if (response.statusCode != HttpStatus.SWITCHING_PROTOCOLS ||
        response.headers[HttpHeaders.CONNECTION] == null ||
        !response.headers[HttpHeaders.CONNECTION].any(
              (value) => value.toLowerCase() == "upgrade") ||
        response.headers.value(HttpHeaders.UPGRADE).toLowerCase() != "websocket") {
        error("Connection to '$uri' was not upgraded to websocket");
      }
      String accept = response.headers.value("Sec-WebSocket-Accept");
      if (accept == null) {
        error("Response did not contain a 'Sec-WebSocket-Accept' header");
      }
      SHA1 sha1 = new SHA1();
      sha1.add("$nonce$_webSocketGUID".codeUnits);
      List<int> expectedAccept = sha1.close();
      List<int> receivedAccept = CryptoUtils.base64StringToBytes(accept);
      if (expectedAccept.length != receivedAccept.length) {
        error("Response header 'Sec-WebSocket-Accept' is the wrong length");
      }
      for (int i = 0; i < expectedAccept.length; i++) {
        if (expectedAccept[i] != receivedAccept[i]) {
          error("Bad response 'Sec-WebSocket-Accept' header");
        }
      }
      var protocol = response.headers.value('Sec-WebSocket-Protocol');
      return response.detachSocket()
        .then((socket) => new WebSocket.fromUpgradedSocket(socket, protocol: protocol, serverSide: false));
    });
  }
}

/// Generates a random socket port.
Future<int> getRandomSocketPort() async {
  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4.address, 0);
  var port = server.port;
  await server.close();
  return port;
}

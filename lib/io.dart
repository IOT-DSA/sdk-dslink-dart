/// DSLink SDK IO Utilities
library dslink.io;

import "dart:async";
import "dart:convert";
import "dart:io";

Stream<String> readStdinText() => stdin.transform(UTF8.decoder);
Stream<String> readStdinLines() =>
    readStdinText().transform(new LineSplitter());

class HttpHelper {
  static HttpClient client = new HttpClient();

  static Future<HttpClientRequest> createRequest(String method, String url, {Map<String, String> headers}) async {
    var request = await client.openUrl(method, Uri.parse(url));
    if (headers != null) {
      headers.forEach(request.headers.set);
    }
    return request;
  }

  static Future<List<int>> readBytesFromResponse(HttpClientResponse response) async {
    return await response.fold([], (a, b) {
      a.addAll(b);
      return a;
    });
  }

  static Future<String> fetchUrl(String url, {Map<String, String> headers}) async {
    var request = await createRequest("GET", url, headers: headers);
    var response = await request.close();
    return UTF8.decode(await readBytesFromResponse(response));
  }

  static Future<dynamic> fetchJSON(String url, {Map<String, String> headers}) async {
    return JSON.decode(await fetchUrl(url, headers: headers));
  }
}

library dslink.server;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'common.dart';
import 'utils.dart';
import 'requester.dart';
import 'responder.dart';

import 'src/crypto/pk.dart';
import 'src/http/websocket_conn.dart';

export 'src/crypto/pk.dart';

part 'src/http/server_http_conn.dart';
part 'src/http/server_link.dart';
part 'src/http/server.dart';

ContentType _jsonContentType = new ContentType("application", "json", charset: "utf-8");

void updateResponseBeforeWrite(HttpRequest request, [int statusCode = HttpStatus.OK, ContentType contentType]) {
  var response = request.response;
  response.statusCode = statusCode;
  response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS, GET");
  response.headers.add('Access-Control-Allow-Headers', "Content-Type");
  var uri = request.uri;

  if (uri.scheme == 'https') {
    response.headers.add('Access-Control-Allow-Origin', 'https://${uri.host}${uri.port != null ? ":${uri.port}":""}');
  } else {
    response.headers.add('Access-Control-Allow-Origin', '*');
  }

  if (contentType == null) {
    contentType = _jsonContentType;
  }
  response.headers.contentType = contentType;
}

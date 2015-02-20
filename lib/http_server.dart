library dslink.http_server;

import 'common.dart';
import 'dart:io';
import 'src/crypto/pk.dart';
import 'utils.dart';
import 'requester.dart';
import 'responder.dart';
import 'src/http/websocket_conn.dart';
import 'dart:convert';
import 'dart:async';

part 'src/http/server_http_conn.dart';
part 'src/http/server_link.dart';
part 'src/http/server.dart';



ContentType _jsonContentType = new ContentType("application", "json", charset: "utf-8");

void updateResponseBeforeWrite(HttpResponse response, [int statusCode = HttpStatus.OK, ContentType contentType]) {
  response.statusCode = statusCode;
  response.headers.add("Access-Control-Allow-Methods", "POST, OPTIONS, GET");
  response.headers.add('Access-Control-Allow-Headers', "Content-Type");
  response.headers.add('Access-Control-Allow-Origin', '*');
  if (contentType == null) {
    contentType = _jsonContentType;
  }
  response.headers.contentType = contentType;
}

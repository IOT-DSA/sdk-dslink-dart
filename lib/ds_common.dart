library dslink.common;

import 'dart:async';

abstract class DsConnection {
  void send(Map data);
  Stream<Map> get onReceive;
  /// whether the connection is ready to send and receive data
  bool get isReady;
  /// when onReady is triggered, isReady must be true 
  Future<DsConnection> get onReady;
}

abstract class DsSession {
  DsConnection get requestConn;
  DsConnection get respondConn;
}

abstract class DsBaseNode {
  /// configs can be Map List or any primitive types
  Object getConfig(String name);
  String getAttribute(String name);
  DsBaseNode getChild(String name);
}

enum DsErrorPhase { RequestError, ResponseError }

class DsError {
  /// type of 
  String type;
  String detail;
  String msg;
  String path;
  DsErrorPhase phase;
}
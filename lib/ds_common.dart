library dslink.common;

import 'dart:async';

part 'src/common/node.dart';

abstract class DsConnection {
  void send(Map data);
  
  Stream<Map> get onReceive;
  /// whether the connection is ready to send and receive data
  bool get isReady;
  /// when onReady is triggered, isReady must be true 
  Future<DsConnection> get onReady;
}

abstract class DsConnectionBase implements DsConnection {
  Completer _readyCompleter = new Completer();
  bool _isReady = false;
  
  @override
  bool get isReady => _isReady;
  
  @override
  Future<DsConnection> get onReady => _readyCompleter.future;
  
  void ready() {
    _readyCompleter.complete(this);
    _isReady = true;
  }
}

abstract class DsSession {
  DsConnection get requestConn;
  DsConnection get responseConn;
}

class DsStreamStatus {
  static const String initialize = 'initialize';
  static const String open = 'open';
  static const String closed = 'closed';
}

class DsErrorPhase {
  static const String request = 'request';
  static const String response = 'response';
}

class DsError {
  /// type of error
  String type;
  String detail;
  String msg;
  String path;
  String phase;
}
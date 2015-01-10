library dslink.common;

import 'dart:async';
import 'ds_requester.dart';
import 'ds_responder.dart';

part 'src/common/node.dart';

abstract class DsConnection {
  /// send data for a single request or response method
  void send(Map data);
  /// a processor function that returns before the data is sent
  /// same processor won't be added to the list twice
  /// this makes sure a data won't get sent multiple times in same frame
  void addProcessor(void processor());
  /// receive data from method stream
  Stream<Map> get onReceive;
  
  /// whether the connection is ready to send and receive data
  bool get isReady;
  
  /// 
  Future<DsConnection> get onDisconnected;

  /// close the connection
  void close();
  
  //
}

abstract class DsSession {
  DsRequester get requester;
  DsResponder get responder;
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
  
  DsError(this.msg, {this.detail, this.type, this.path, this.phase: DsErrorPhase.response});
  
  Map serialize() {
    Map rslt = {
      'msg': msg
    };
    if (type != null) {
      rslt['type'] = type;
    }
    if (path != null) {
      rslt['path'] = path;
    }
    if (phase == DsErrorPhase.request) {
      rslt['phase'] = DsErrorPhase.request;
    }
    if (detail != null) {
      rslt['detail'] = detail;
    }
    return rslt;
  }
}

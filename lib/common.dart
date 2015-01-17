library dslink.common;

import 'dart:async';
import 'dart:convert';
import 'requester.dart';
import 'responder.dart';

import 'package:quiver/core.dart';
import 'src/crypto/pk.dart';

part 'src/common/node.dart';
part 'src/common/table.dart';
part 'src/common/value.dart';
part 'src/common/connection_channel.dart';
part 'src/common/connection_handler.dart';

JsonUtf8Encoder jsonUtf8Encoder = new JsonUtf8Encoder();

List foldList(List a, List b) {
  return a..addAll(b);
}

abstract class Connection {
  ConnectionChannel get requesterChannel;
  ConnectionChannel get responderChannel;
  /// trigger when requester channel is Ready
  Future<ConnectionChannel> get onRequesterReady;

  /// notify the connection channel need to send data
  void requireSend();
  /// close the connection
  void close();
}
abstract class ServerConnection extends Connection {
  /// send a server command to client such as salt string, or allowed:true
  void addServerCommand(String key, Object value);
}

abstract class ClientConnection extends Connection {
}

abstract class ConnectionChannel {
  /// raw connection need to handle error and resending of data, so it can only send one map at a time
  /// a new getData function will always overwrite the previous one;
  /// requester and responder should handle the merging of methods
  void sendWhenReady(List getData());
  /// receive data from method stream
  Stream<List> get onReceive;

  /// whether the connection is ready to send and receive data
  bool get isReady;

  Future<ConnectionChannel> get onDisconnected;
}

abstract class Session {
  DsRequester get requester;
  Responder get responder;
  
  SecretNonce get nonce;
  
  /// trigger when requester channel is Ready
  Future<DsRequester> get onRequesterReady;
}

abstract class ServerSession extends Session {
  PublicKey get publicKey;
}

abstract class ClientSession extends Session {
  PrivateKey get privateKey;
  /// shortPolling is only valid in http mode
  updateSalt(String salt, [bool shortPolling = false]);
}

class StreamStatus {
  static const String initialize = 'initialize';
  static const String open = 'open';
  static const String closed = 'closed';
}

class ErrorPhase {
  static const String request = 'request';
  static const String response = 'response';
}

class DSError {
  /// type of error
  String type;
  String detail;
  String msg;
  String path;
  String phase;

  DSError(this.msg, {this.detail, this.type, this.path, this.phase: ErrorPhase.response});

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
    if (phase == ErrorPhase.request) {
      rslt['phase'] = ErrorPhase.request;
    }
    if (detail != null) {
      rslt['detail'] = detail;
    }
    return rslt;
  }
}

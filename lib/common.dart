/// Shared APIs between all DSA Components.
library dslink.common;

import 'dart:async';
import 'dart:convert';

import 'requester.dart';
import 'responder.dart';

import 'src/crypto/pk.dart';
import 'utils.dart';

part 'src/common/node.dart';
part 'src/common/table.dart';
part 'src/common/value.dart';
part 'src/common/connection_channel.dart';
part 'src/common/connection_handler.dart';
part 'src/common/permission.dart';
part 'src/common/default_defs.dart';

abstract class Connection {
  ConnectionChannel get requesterChannel;

  ConnectionChannel get responderChannel;

  /// trigger when requester channel is Ready
  Future<ConnectionChannel> get onRequesterReady;

  /// return true if it's authentication error
  Future<bool> get onDisconnected;

  /// notify the connection channel need to send data
  void requireSend();

  /// close the connection
  void close();
}

abstract class ServerConnection extends Connection {
  /// send a server command to client such as salt string, or allowed:true
  void addServerCommand(String key, Object value);
}

abstract class ClientConnection extends Connection {}

abstract class ConnectionChannel {
  /// raw connection need to handle error and resending of data, so it can only send one map at a time
  /// a new getData function will always overwrite the previous one;
  /// requester and responder should handle the merging of methods
  void sendWhenReady(List getData());

  /// receive data from method stream
  Stream<List> get onReceive;

  /// whether the connection is ready to send and receive data
  bool get isReady;

  bool get connected;

  Future<ConnectionChannel> get onDisconnected;

  Future<ConnectionChannel> get onConnected;
}

/// Base Class for Links
abstract class Link {
  Requester get requester;
  Responder get responder;

  ECDH get nonce;

  /// trigger when requester channel is Ready
  Future<Requester> get onRequesterReady;
}

/// Base Class for Server Link implementations.
abstract class ServerLink extends Link {
  String get dsId;

  String get session;

  PublicKey get publicKey;

  void close();
}

/// Base Class for Client Link implementations.
abstract class ClientLink extends Link {
  PrivateKey get privateKey;

  /// shortPolling is only valid in http mode
  /// saltId: 0 salt, 1:saltS, 2:saltL
  updateSalt(String salt, [int saltId = 0]);

  void connect();
}

abstract class ServerLinkManager {
  void addLink(ServerLink link);

  void removeLink(ServerLink link);

  ServerLink getLink(String dsId, {String sessionId: ''});

  Requester getRequester(String dsId);

  Responder getResponder(String dsId, NodeProvider nodeProvider,
      [String sessionId = '']);
}

/// DSA Stream Status
class StreamStatus {
  /// Stream should be initialized.
  static const String initialize = 'initialize';
  /// Stream is open.
  static const String open = 'open';
  /// Stream is closed.
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

  DSError(this.type,
      {this.msg, this.detail, this.path, this.phase: ErrorPhase.response});
  DSError.fromMap(Map m) {
    if (m['type'] is String) {
      type = m['type'];
    }
    if (m['msg'] is String) {
      msg = m['msg'];
    }
    if (m['path'] is String) {
      path = m['path'];
    }
    if (m['phase'] is String) {
      phase = m['phase'];
    }
    if (m['detail'] is String) {
      detail = m['detail'];
    }
  }

  String getMessage() {
    if (msg != null) {
      return msg;
    }
    if (type != null) {
      // TODO, return normal case instead of camel case
      return type;
    }
    return 'Error';
  }

  Map serialize() {
    Map rslt = {};
    if (msg != null) {
      rslt['msg'] = msg;
    }
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

  static final DSError PERMISSION_DENIED = new DSError('permissionDenied');
  static final DSError INVALID_METHOD = new DSError('invalidMethod');
  static final DSError NOT_IMPLEMENTED = new DSError('notImplemented');
  static final DSError INVALID_PATH = new DSError('invalidPath');
  static final DSError INVALID_PATHS = new DSError('invalidPaths');
  static final DSError INVALID_VALUE = new DSError('invalidValue');
  static final DSError INVALID_PARAMETER = new DSError('invalidParameter');
  static final DSError DISCONNECTED =
      new DSError('disconnected', phase: ErrorPhase.request);
}

/// Marks something as being unspecified.
const Unspecified unspecified = const Unspecified();

/// Unspecified means that something has never been set.
class Unspecified {
  const Unspecified();
}

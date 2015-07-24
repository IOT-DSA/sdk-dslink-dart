library dslink.http.websocket;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../../common.dart';
import '../../utils.dart';

class WebSocketConnection extends Connection {
  PassiveChannel _responderChannel;

  ConnectionChannel get responderChannel => _responderChannel;

  PassiveChannel _requesterChannel;

  ConnectionChannel get requesterChannel => _requesterChannel;

  Completer<ConnectionChannel> onRequestReadyCompleter =
      new Completer<ConnectionChannel>();

  Future<ConnectionChannel> get onRequesterReady =>
      onRequestReadyCompleter.future;

  Completer<bool> _onDisconnectedCompleter = new Completer<bool>();

  Future<bool> get onDisconnected => _onDisconnectedCompleter.future;

  final ClientLink clientLink;

  final WebSocket socket;

  /// clientLink is not needed when websocket works in server link
  WebSocketConnection(this.socket,
      {this.clientLink, bool enableTimeout: false}) {
    _responderChannel = new PassiveChannel(this, true);
    _requesterChannel = new PassiveChannel(this, true);
    socket.listen(onData, onDone: _onDone);
    socket.add(fixedBlankData);
    if (enableTimeout) {
      pingTimer = new Timer.periodic(new Duration(seconds: 20), onPingTimer);
    }
    // TODO(rinick): when it's used in client link, wait for the server to send {allowed} before complete this
  }

  Timer pingTimer;

  /// set to true when data is sent, reset the flag every 20 seconds
  /// since the previous ping message will cause the next 20 seoncd to have a message
  /// max interval between 2 ping messages is 40 seconds
  bool _dataSent = false;

  /// add this count every 20 seconds, set to 0 when receiving data
  /// when the count is 3, disconnect the link (>=60 seconds)
  int _dataReceiveCount = 0;

  int throughput = 0;

  void onPingTimer(Timer t) {
    if (_dataReceiveCount >= 3) {
      this.close();
      return;
    }

    _dataReceiveCount++;

    if (_dataSent) {
      _dataSent = false;
      return;
    }
    this.addConnCommand(null, null);
  }

  void requireSend() {
    if (!_sending) {
      _sending = true;
      DsTimer.callLater(_send);
    }
  }

  /// special server command that need to be merged into message
  /// now only 2 possible value, salt, allowed
  Map _serverCommand;

  /// add server command, will be called only when used as server connection
  void addConnCommand(String key, Object value) {
    if (_serverCommand == null) {
      _serverCommand = {};
    }
    if (key != null) {
      _serverCommand[key] = value;
    }
    
    requireSend();
  }

  BinaryInCache binaryInCache = new BinaryInCache();
  void onData(dynamic data) {
    if (_onDisconnectedCompleter.isCompleted) {
      return;
    }
    logger.finest("begin WebSocketConnection.onData");
    if (!onRequestReadyCompleter.isCompleted) {
      onRequestReadyCompleter.complete(_requesterChannel);
    }
    _dataReceiveCount = 0;
    Map m;
    if (data is List<int>) {
      throughput += data.length;
      if (data.length != 0 && data[0] == 0) {
        logger.finest(" receive binary length ${data.length}");
        // binary channel
        binaryInCache.receiveData(data);
        return;
      }
      try {
        m = DsJson.decodeFrame(UTF8.decode(data), binaryInCache);
        logger.fine("WebSocket JSON (bytes): ${m}");
      } catch (err, stack) {
        logger.fine(
            "Failed to decode JSON bytes in WebSocket Connection", err, stack);
        close();
        return;
      }
      bool needAck = false;
      if (m['responses'] is List && (m['responses'] as List).length > 0) {
        needAck = true;
        // send responses to requester channel
        _requesterChannel.onReceiveController.add(m['responses']);
      }
      if (m['requests'] is List && (m['requests'] as List).length > 0) {
        needAck = true;
        // send requests to responder channel
        _responderChannel.onReceiveController.add(m['requests']);
      }
      if (m['ack'] is int) {
        ack(m['ack']);
      }
      if (needAck) {
        Object msgId = m['msg'];
        if (msgId != null) {
          addConnCommand('ack', msgId);
        }
      }
    } else if (data is String) {
      throughput += data.length;
      try {
        m = DsJson.decodeFrame(data, binaryInCache);
        logger.fine("WebSocket JSON: ${m}");
      } catch (err) {
        logger.severe("Failed to decode JSON from WebSocket Connection", err);
        close();
        return;
      }
      if (m['salt'] is String && clientLink != null) {
        clientLink.updateSalt(m['salt']);
      }
      bool needAck = false;
      if (m['responses'] is List && (m['responses'] as List).length > 0) {
        needAck = true;
        // send responses to requester channel
        _requesterChannel.onReceiveController.add(m['responses']);
      }
      if (m['requests'] is List && (m['requests'] as List).length > 0) {
        needAck = true;
        // send requests to responder channel
        _responderChannel.onReceiveController.add(m['requests']);
      }
      if (m['ack'] is int) {
        ack(m['ack']);
      }
      if (needAck) {
        Object msgId = m['msg'];
        if (msgId != null) {
          addConnCommand('ack', msgId);
        }
      }
    }

    logger.finest("end WebSocketConnection.onData");
  }
  int msgId = 0;
  bool _sending = false;
  void _send() {
    _sending = false;
    bool needSend = false;
    Map m;
    if (_serverCommand != null) {
      m = _serverCommand;
      _serverCommand = null;
      needSend = true;
    } else {
      m = {};
    }
    List pendingAck = [];
    int ts = (new DateTime.now()).millisecondsSinceEpoch;
    ProcessorResult rslt = _responderChannel.getSendingData(ts, msgId);
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m['responses'] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    rslt = _requesterChannel.getSendingData(ts, msgId);
    if (rslt != null) {
      if (rslt.messages.length > 0) {
        m['requests'] = rslt.messages;
        needSend = true;
      }
      if (rslt.processors.length > 0) {
        pendingAck.addAll(rslt.processors);
      }
    }
    if (needSend) {
      if (pendingAck.length > 0) {
        pendingAcks.add(new ConnectionAckGroup(msgId, ts, pendingAck));
      }
      m['msg'] = msgId++;
      addData(m);
      _dataSent = true;
    }
  }

  BinaryOutCache binaryOutCache = new BinaryOutCache();
  void addData(Map m) {
    String json = DsJson.encodeFrame(m, binaryOutCache);
    if (binaryOutCache.hasData) {
      logger.finest("send binary");
      socket.add(binaryOutCache.export());
    }
    logger.finest('send: $json');
    throughput += json.length;
    socket.add(json);
  }

  void _onDone() {
    logger.fine("socket disconnected");
    if (!_requesterChannel.onReceiveController.isClosed) {
      _requesterChannel.onReceiveController.close();
    }
    if (!_requesterChannel.onDisconnectController.isCompleted) {
      _requesterChannel.onDisconnectController.complete(_requesterChannel);
    }
    if (!_responderChannel.onReceiveController.isClosed) {
      _responderChannel.onReceiveController.close();
    }
    if (!_responderChannel.onDisconnectController.isCompleted) {
      _responderChannel.onDisconnectController.complete(_responderChannel);
    }
    if (!_onDisconnectedCompleter.isCompleted) {
      _onDisconnectedCompleter.complete(false);
    }
    if (pingTimer != null) {
      pingTimer.cancel();
    }
  }

  void close() {
    if (socket.readyState == WebSocket.OPEN ||
        socket.readyState == WebSocket.CONNECTING) {
      socket.close();
    }
    _onDone();
  }
}

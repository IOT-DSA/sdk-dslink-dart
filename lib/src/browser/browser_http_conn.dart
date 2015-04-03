part of dslink.browser_client;

class HttpBrowserConnection implements ClientConnection {
  PassiveChannel _responderChannel;

  ConnectionChannel get responderChannel => _responderChannel;

  PassiveChannel _requesterChannel;

  ConnectionChannel get requesterChannel => _requesterChannel;

  Completer<ConnectionChannel> _onRequestReadyCompleter =
  new Completer<ConnectionChannel>();

  Future<ConnectionChannel> get onRequesterReady =>
  _onRequestReadyCompleter.future;

  Completer<Connection> _onDisconnectedCompleter = new Completer<Connection>();

  Future<Connection> get onDisconnected => _onDisconnectedCompleter.future;

  final String url;
  final ClientLink clientLink;
  final bool withCredentials;
  String saltL;
  String saltS;

  HttpBrowserConnection(this.url, this.clientLink, this.saltL, this.saltS,
                        [this.withCredentials = false]) {
    _responderChannel = new PassiveChannel(this);
    _requesterChannel = new PassiveChannel(this);
    // TODO, wait for the server to send {allowed} before complete this
    _onRequestReadyCompleter.complete(new Future.value(_requesterChannel));
    requireSend();
  }

  bool _pendingCheck = false;
  bool _pendingSend = false;

  void requireSend() {
    _pendingSend = true;
    if (!_pendingCheck) {
      _pendingCheck = true;
      DsTimer.callLaterOnce(_checkSend);
    }
  }

  void close() {
  }

  bool _sending = false;
  bool _sendingS = false;

  void _checkSend() {
    _pendingCheck = false;
    if (_pendingSend) {
      if (_sending == false) {
        _send();
      } else if (_sendingS == false) {
        _send(true);
      }
    }
  }

  void _send([bool shortPoll = false]) {
    _pendingSend = false;
    // long poll should always send even it's blank
    bool needSend = !shortPoll;
    Map m = {};
    if (_responderChannel.getData != null) {
      List rslt = _responderChannel.getData();
      if (rslt != null && rslt.length != 0) {
        m['responses'] = rslt;
        needSend = true;
      }
    }
    if (_requesterChannel.getData != null) {
      List rslt = _requesterChannel.getData();
      if (rslt != null && rslt.length != 0) {
        m['requests'] = rslt;
        needSend = true;
      }
    }
    if (needSend) {
      Uri connUri = Uri.parse('$url&');
      if (shortPoll) {
        printDebug('http sendS: $m');
        _sendingS = true;
        connUri =
        Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');
      } else {
        printDebug('http send: $m');
        _sending = true;
        connUri =
        Uri.parse('$url&authL=${this.clientLink.nonce.hashSalt(saltL)}');
      }
      HttpRequest
      .request(connUri.toString(),
      method: 'POST',
      withCredentials: withCredentials,
      mimeType: 'application/json',
      sendData: JSON.encode(m))
      .then(//
          (HttpRequest request) {
          if (shortPoll) {
            _onDataS(request.responseText);
          } else {
            _sending = true;
            _onData(request.responseText);
          }
        });
    }
  }

  void _onData(String response) {
    _sending = false;
    // always send back after receiving long polling response
    requireSend();
    Map m;
    try {
      m = JSON.decode(response);
      printDebug('http receive: $m');
    } catch (err) {
      return;
    }
    if (m['saltL'] is String) {
      saltL = m['saltL'];
      clientLink.updateSalt(saltL, 2);
    }
    if (m['responses'] is List) {
      // send responses to requester channel
      _requesterChannel.onReceiveController.add(m['responses']);
    }
    if (m['requests'] is List) {
      // send requests to responder channel
      _responderChannel.onReceiveController.add(m['requests']);
    }
  }

  void _onDataS(String response) {
    _sendingS = false;
    Map m;
    try {
      m = JSON.decode(response);
    } catch (err) {
      return;
    }
    if (m['saltS'] is String) {
      saltS = m['saltS'];
      clientLink.updateSalt(saltS, 1);
    }
    if (_pendingSend && !_pendingCheck) {
      _checkSend();
    }
  }
}

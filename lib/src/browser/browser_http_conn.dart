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

  Completer<bool> _onDisconnectedCompleter = new Completer<bool>();
  Future<bool> get onDisconnected => _onDisconnectedCompleter.future;

  bool _connectedOnce = false;
  void connected(){
    if (_connectedOnce) return;
    _connectedOnce = true;
    _responderChannel.updateConnect();
    _requesterChannel.updateConnect();
  }

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
    _sendL();
  }

  bool _pendingCheck = false;
  bool _pendingSendS = false;

  void requireSend() {
    _pendingSendS = true;
    if (!_pendingCheck) {
      _pendingCheck = true;
      DsTimer.callLaterOnce(_checkSend);
    }
  }

  void close() {}

  bool _sendingL = false;
  bool _sendingS = false;

  void _checkSend() {
    _pendingCheck = false;
    if (_pendingSendS) {
      if (_sendingS == false) {
        _sendS();
      }
    }
  }
  _sendL() async {
    Uri connUri =
        Uri.parse('$url&authL=${this.clientLink.nonce.hashSalt(saltL)}');
    HttpRequest request;
    try {
      request = await HttpRequest.request(connUri.toString(),
          method: 'POST',
          withCredentials: withCredentials,
          mimeType: 'application/json',
          sendData: '{}');
    } catch (err) {
      _onDataErrorL(err);
      return;
    }
    _onDataL(request.responseText);
  }
  void _onDataErrorL(Object err) {
    printDebug('http long error:$err');
    if (!_connectedOnce) {
      _onDone();
      return;
    } else if (!_done) {
      _needRetryL = true;
      DsTimer.timerOnceBefore(retry, retryDelay * 1000);
      if (retryDelay < 60) {
        retryDelay ++;
      }
    }
  }
  bool _needRetryL = false;
  void retryL() {
    _needRetryL = false;
    _sendL();
  }

  _sendS() async {
    _pendingSendS = false;
    bool needSend = false;
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
      printDebug('http sendS: $m');
      HttpRequest request;
      try {
        _sendingS = true;
        _lastRequestS = JSON.encode(m);
        connUri =
            Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');
        request = await HttpRequest.request(connUri.toString(),
            method: 'POST',
            withCredentials: withCredentials,
            mimeType: 'application/json',
            sendData: _lastRequestS);
      } catch (err) {
        _onDataErrorS(err);
        return;
      }
      _onDataS(request.responseText);
    }
  }

  void _onDataErrorS(Object err) {
    printDebug('http short error:$err');
    if (!_connectedOnce) {
      _onDone();
      return;
    } else if (!_done) {
      _needRetryS = true;
      DsTimer.timerOnceBefore(retry, retryDelay * 1000);
    }
  }
  String _lastRequestS;
  bool _needRetryS = false;
  void retryS() {
    _needRetryS = false;
    Uri connUri = Uri.parse('$url&');
    printDebug('re-sendS: $_lastRequestS');
    connUri = Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');
    HttpRequest
        .request(connUri.toString(),
            method: 'POST',
            withCredentials: withCredentials,
            mimeType: 'application/json',
            sendData: _lastRequestS)
        .then(//
            (HttpRequest request) {
      _onDataS(request.responseText);
    });
  }

  void _onDataL(String response) {
    connected();
    _sendingL = false;
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
    connected();
    _sendingS = false;
    // always send back after receiving long polling response
    Map m;
    try {
      m = JSON.decode(response);
      printDebug('http receive: $m');
    } catch (err) {
      return;
    }
    if (m['saltS'] is String) {
      saltL = m['saltS'];
      clientLink.updateSalt(saltS, 1);
    }
    if (_pendingSendS && !_pendingCheck) {
      _checkSend();
    }
  }

  /// retry when network is disconnected
  void retry() {
    if (_needRetryL) {
      retryL();
    }
    if (_needRetryS) {
      retryS();
    }
  }

  bool _done = false;
  int retryDelay = 1;
  bool _authError = false;
  void _onDone() {
    _done = true;
    printDebug('http disconnected');
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
      _onDisconnectedCompleter.complete(_authError);
    }
  }
}

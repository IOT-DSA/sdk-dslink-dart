part of dslink.client;

class HttpClientConnection implements ClientConnection {
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

  bool connectedOnce = false;
  
  final String url;
  final ClientLink clientLink;

  String salt;
  String saltS;
  HttpClientConnection(this.url, this.clientLink, this.salt, this.saltS) {
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
  bool _sending = false;
  bool _sendingS = false;

  void _checkSend() {
    _pendingCheck = false;
    if (_pendingSendS) {
      if (_sendingS == false) {
        _sendS();
      }
    }
  }

  static List<int> _fixedLongPollData = jsonUtf8Encoder.convert({});
  void _sendL() {
    HttpClient client = new HttpClient();
    Uri connUri =
        Uri.parse('$url&auth=${this.clientLink.nonce.hashSalt(salt)}');
    client.postUrl(connUri).then((HttpClientRequest request) {
      request.add(_fixedLongPollData);
      request.close().then(_onData).catchError(_onDataError);
    });
  }
  void _onDataError(Object err) {
    printDebug('http long error:$err');
    if (!connectedOnce) {
      _onDone();
      return;
    } else if (!_done){
      _needRetryL = true;
      DsTimer.callOnceBefore(retry, retryDelay*1000);
    }
  }
  bool _needRetryL = false;
  void retryL() {
    _needRetryL = false;
    _sendL();
  }
  void _onData(HttpClientResponse response) {
    if (response.statusCode != 200){
      printDebug('http long response.statusCode:${response.statusCode}');
      if (response.statusCode == HttpStatus.UNAUTHORIZED){
        _onDone();
        return;
      }
    }
    response.fold([], foldList).then((List<int> merged) {
      connectedOnce = true;
      _sending = false;
      // always send back after receiving long polling response
      Map m;
      try {
        m = JSON.decode(UTF8.decode(merged));
        printDebug('http receive: $m');
      } catch (err) {
        return;
      }
      if (m['salt'] is String) {
        salt = m['salt'];
        clientLink.updateSalt(salt);
      }
      _sendL();
      if (m['responses'] is List) {
        // send responses to requester channel
        _requesterChannel.onReceiveController.add(m['responses']);
      }
      if (m['requests'] is List) {
        // send requests to responder channel
        _responderChannel.onReceiveController.add(m['requests']);
      }
    });
  }
  
  void _sendS() {
    _pendingSendS = false;
    // long poll should always send even it's blank
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
      printDebug('http send: $m');
      _sendingS = true;
      HttpClient client = new HttpClient();
      Uri connUri =
          Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');

      client.postUrl(connUri).then((HttpClientRequest request) {
        _lastRequestS = jsonUtf8Encoder.convert(m); 
        request.add(_lastRequestS);
        request.close().then(_onDataS).catchError(_onDataErrorS);
      });
    }
  }
  
  void _onDataErrorS(Object err) {
    printDebug('http short error:$err');
    if (!connectedOnce) {
      _onDone();
      return;
    } else if (!_done){
      _needRetryS = true;
      DsTimer.callOnceBefore(retry, retryDelay*1000);
    }
  }
  List<int> _lastRequestS;
  bool _needRetryS = false;
  void retryS(){
    _needRetryS = false;
    HttpClient client = new HttpClient();
    Uri connUri =
        Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');
    client.postUrl(connUri).then((HttpClientRequest request) {
      request.add(_lastRequestS);
      request.close().then(_onDataS).catchError(_onDataErrorS);
    });    
  }
  
  void _onDataS(HttpClientResponse response) {
    if (response.statusCode != 200){
       printDebug('http short response.statusCode:${response.statusCode}');
       if (response.statusCode == HttpStatus.UNAUTHORIZED){
         _onDone();
       }
     }
    response.fold([], foldList).then((List<int> merged) {
      connectedOnce = true;
      _sendingS = false;
      Map m;
      try {
        m = JSON.decode(UTF8.decode(merged));
      } catch (err) {
        return;
      }
      if (m['saltS'] is String) {
        saltS = m['saltS'];
        clientLink.updateSalt(saltS, true);
      }
      if (_pendingSendS && !_pendingCheck) {
        _checkSend();
      }
    });
  }
  
  /// retry when network is disconnected
  void retry(){
    if (_needRetryL) {
      retryL();
    }
    if (_needRetryS){
      retryS();
    }
  }
  
  bool _done = false;
  int retryDelay = 1;
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
      _onDisconnectedCompleter.complete(this);
    }
  }
}

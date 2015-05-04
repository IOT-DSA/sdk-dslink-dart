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

  String saltL;
  String saltS;
  HttpClientConnection(this.url, this.clientLink, this.saltL, this.saltS) {
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

  void close() {
    //TODO

  }
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

  static List<int> _fixedLongPollData = UTF8.encode(DsJson.encode(({})));
  _sendL() async {
    HttpClient client = new HttpClient();
    HttpClientResponse resp;
    try {
      Uri connUri =
          Uri.parse('$url&authL=${this.clientLink.nonce.hashSalt(saltL)}');
      HttpClientRequest request = await client.postUrl(connUri);
      request.add(_fixedLongPollData);
      resp = await request.close();
    } catch (err) {
      _onDataErrorL(err);
      return;
    }
    _onDataL(resp);
  }
  void _onDataErrorL(Object err) {
    logger.fine('http long error: $err');
    if (!_connectedOnce) {
      _onDone();
      return;
    } else if (!_done){
      _needRetryL = true;
      DsTimer.timerOnceBefore(retry, retryDelay * 1000);
      if (retryDelay < 60) {
        retryDelay++;
      }
    }
  }
  bool _needRetryL = false;
  void retryL() {
    _needRetryL = false;
    _sendL();
  }
  void _onDataL(HttpClientResponse response) {
    if (response.statusCode != 200){
      logger.fine('http long response.statusCode:${response.statusCode}');
      if (response.statusCode == HttpStatus.UNAUTHORIZED){
        _authError = true;
        _onDone();
        return;
      }
    }
    response.fold([], foldList).then((List<int> merged) {
      connected();
      _sending = false;
      // always send back after receiving long polling response
      Map m;
      try {
        m = DsJson.decode(UTF8.decode(merged));
        logger.fine('http receive: $m');
      } catch (err) {
        return;
      }
      if (m['saltL'] is String) {
        saltL = m['saltL'];
        clientLink.updateSalt(saltL, 2);
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

  _sendS() async{
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
      HttpClientResponse resp;
      logger.fine('http send: $m');
      try{
        _sendingS = true;
        HttpClient client = new HttpClient();
        Uri connUri =
            Uri.parse('$url&authS=${this.clientLink.nonce.hashSalt(saltS)}');

        HttpClientRequest request = await client.postUrl(connUri);
        _lastRequestS = UTF8.encode(JSON.encode(m));
        request.add(_lastRequestS);
        resp = await request.close();
      } catch(err) {
        _onDataErrorS(err);
        return;
      }
      _onDataS(resp);
    }
  }

  void _onDataErrorS(Object err) {
    logger.fine('http short error:$err');
    if (!_connectedOnce) {
      _onDone();
      return;
    } else if (!_done){
      _needRetryS = true;
      DsTimer.timerOnceBefore(retry, retryDelay*1000);
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
       logger.fine('http short response.statusCode:${response.statusCode}');
       if (response.statusCode == HttpStatus.UNAUTHORIZED){
         _authError = true;
         _onDone();
       }
     }
    response.fold([], foldList).then((List<int> merged) {
      connected();
      _sendingS = false;
      Map m;
      try {
        m = DsJson.decode(UTF8.decode(merged));
      } catch (err) {
        return;
      }
      if (m['saltS'] is String) {
        saltS = m['saltS'];
        clientLink.updateSalt(saltS, 1);
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
  bool _authError = false;
  void _onDone() {
    _done = true;
    logger.fine('http disconnected');
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

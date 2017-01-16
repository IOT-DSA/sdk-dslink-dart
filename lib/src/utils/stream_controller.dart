part of dslink.utils;

class BroadcastStreamController<T> implements StreamController<T> {
  StreamController<T> _controller;
  CachedStreamWrapper<T> _stream;
  Stream<T> get stream => _stream;

  Function onStartListen;
  Function onAllCancel;

  BroadcastStreamController([
    void onStartListen(),
    void onAllCancel(),
    void onListen(callback(T value)),
    bool sync = false
  ]) {
    _controller = new StreamController<T>(sync: sync);
    _stream = new CachedStreamWrapper(
        _controller.stream
            .asBroadcastStream(onListen: _onListen, onCancel: _onCancel),
        onListen);
    this.onStartListen = onStartListen;
    this.onAllCancel = onAllCancel;
  }

  /// whether there is listener or not
  bool _listening = false;

  /// whether _onStartListen is called
  bool _listenState = false;
  void _onListen(StreamSubscription<T> subscription) {
    if (!_listenState) {
      if (onStartListen != null) {
        onStartListen();
      }
      _listenState = true;
    }
    _listening = true;
  }

  void _onCancel(StreamSubscription<T> subscription) {
    _listening = false;
    if (onAllCancel != null) {
      if (!_delayedCheckCanceling) {
        _delayedCheckCanceling = true;
        DsTimer.callLater(delayedCheckCancel);
      }
    } else {
      _listenState = false;
    }
  }

  bool _delayedCheckCanceling = false;
  void delayedCheckCancel() {
    _delayedCheckCanceling = false;
    if (!_listening && _listenState) {
      onAllCancel();
      _listenState = false;
    }
  }

  void add(T t) {
    _controller.add(t);
    _stream.lastValue = t;
  }

  void addError(Object error, [StackTrace stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  Future addStream(Stream<T> source, {bool cancelOnError: true}) {
    return _controller.addStream(source, cancelOnError: cancelOnError);
  }

  Future close() {
    return _controller.close();
  }

  Future get done => _controller.done;

  bool get hasListener => _controller.hasListener;

  bool get isClosed => _controller.isClosed;

  bool get isPaused => _controller.isPaused;

  StreamSink<T> get sink => _controller.sink;

  void set onCancel(onCancelHandler()) {
    throw('BroadcastStreamController.onCancel not implemented');
  }

  void set onListen(void onListenHandler()) {
    throw('BroadcastStreamController.onListen not implemented');
  }

  void set onPause(void onPauseHandler()) {
    throw('BroadcastStreamController.onPause not implemented');
  }

  void set onResume(void onResumeHandler()) {
    throw('BroadcastStreamController.onResume not implemented');
  }

  ControllerCancelCallback get onCancel => null;
  ControllerCallback get onListen => null;
  ControllerCallback get onPause => null;
  ControllerCallback get onResume => null;
}

class CachedStreamWrapper<T> extends Stream<T> {
  T lastValue;

  final Stream<T> _stream;
  final Function _onListen;
  CachedStreamWrapper(this._stream, this._onListen);

  @override
  Stream<T> asBroadcastStream(
      {void onListen(StreamSubscription<T> subscription),
      void onCancel(StreamSubscription<T> subscription)}) {
    return this;
  }

  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void onData(T event), {
    Function onError,
    void onDone(),
    bool cancelOnError}) {
    if (_onListen != null) {
      _onListen(onData);
    }

    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError
    );
  }
}

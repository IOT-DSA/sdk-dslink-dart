part of dslink.utils;

class BroadcastStreamController<T> implements StreamController<T> {
  StreamController<T> _controller;
  CachedStreamWrapper<T> _stream;
  Stream<T> get stream => _stream;

  Function _onStartListen;
  Function _onAllCancel;

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
    _onStartListen = onStartListen;
    _onAllCancel = onAllCancel;
  }

  /// whether there is listener or not
  bool _listening = false;

  /// whether _onStartListen is called
  bool _listenState = false;
  void _onListen(StreamSubscription<T> subscription) {
    if (!_listenState) {
      if (_onStartListen != null) {
        _onStartListen();
      }
      _listenState = true;
    }
    _listening = true;
  }

  void _onCancel(StreamSubscription<T> subscription) {
    _listening = false;
    if (_onAllCancel != null) {
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
      _onAllCancel();
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

class CachedStreamWrapper<T> implements Stream<T> {
  T lastValue;

  final Stream<T> _stream;
  final Function _onListen;
  CachedStreamWrapper(this._stream, this._onListen);

  Future<bool> any(bool test(T element)) => _stream.any(test);

  Stream<T> asBroadcastStream(
      {void onListen(StreamSubscription<T> subscription),
      void onCancel(StreamSubscription<T> subscription)}) {
    return this;
  }

  Stream asyncExpand(Stream convert(T event)) => _stream.asyncExpand(convert);

  Stream asyncMap(convert(T event)) => _stream.asyncMap(convert);

  Future<bool> contains(Object needle) => _stream.contains(needle);

  Stream<T> distinct([bool equals(T previous, T next)]) =>
      _stream.distinct(equals);

  Future drain([futureValue]) => _stream.drain(futureValue);

  Future<T> elementAt(int index) => _stream.elementAt(index);

  Future<bool> every(bool test(T element)) => _stream.every(test);

  Stream/*<S>*/ expand/*<S>*/(Iterable/*<S>*/ convert(T value)) => _stream.expand(convert);

  Future<T> get first => _stream.first;

  Future firstWhere(bool test(T element), {Object defaultValue()}) =>
      _stream.firstWhere(test, defaultValue: defaultValue);

  Future/*<S>*/ fold/*<S>*/(var/*=S*/ initialValue,
    /*=S*/ combine(var/*=S*/ previous, T element)) =>
      _stream.fold(initialValue, combine);

  Future forEach(void action(T element)) => _stream.forEach(action);

  Stream<T> handleError(Function onError, {bool test(error)}) =>
      _stream.handleError(onError, test: test);

  bool get isBroadcast => true;

  Future<bool> get isEmpty => _stream.isEmpty;

  Future<String> join([String separator = ""]) => _stream.join(separator);

  Future<T> get last => _stream.last;

  Future lastWhere(bool test(T element), {Object defaultValue()}) =>
      _stream.lastWhere(test, defaultValue: defaultValue);

  Future<int> get length => _stream.length;

  StreamSubscription<T> listen(void onData(T event),
      {Function onError, void onDone(), bool cancelOnError}) {
    if (_onListen != null) {
      _onListen(onData);
    }
    return _stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Stream/*<S>*/ map/*<S>*/(/*=S*/ convert(T event)) => _stream.map(convert);

  Future pipe(StreamConsumer<T> streamConsumer) => _stream.pipe(streamConsumer);

  Future<T> reduce(T combine(T previous, T element)) => _stream.reduce(combine);

  Future<T> get single => _stream.single;

  Future<T> singleWhere(bool test(T element)) => _stream.singleWhere(test);

  Stream<T> skip(int count) => _stream.skip(count);

  Stream<T> skipWhile(bool test(T element)) => _stream.skipWhile(test);

  Stream<T> take(int count) => _stream.take(count);

  Stream<T> takeWhile(bool test(T element)) => _stream.takeWhile(test);

  Stream timeout(Duration timeLimit, {void onTimeout(EventSink sink)}) =>
      _stream.timeout(timeLimit, onTimeout: onTimeout);

  Future<List<T>> toList() => _stream.toList();

  Future<Set<T>> toSet() => _stream.toSet();

  Stream/*<S>*/ transform/*<S>*/(
    StreamTransformer<T, dynamic/*=S*/ > streamTransformer) =>
      _stream.transform(streamTransformer);

  Stream<T> where(bool test(T event)) => _stream.where(test);
}

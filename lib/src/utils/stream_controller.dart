part of dslink.utils;

class BroadcastStreamController<T> implements StreamController<T> {
  StreamController<T> _controller = new StreamController<T>();
  Stream<T> _stream;
  Stream<T> get stream => _stream;

  Function _onStartListen;
  Function _onAllCancel;

  BroadcastStreamController([void onStartListen(), void onAllCancel()]) {
    _stream = _controller.stream.asBroadcastStream(
        onListen: _onListen, onCancel: _onCancel);
    _onStartListen = onStartListen;
    _onAllCancel = onAllCancel;
  }

  void _onListen(StreamSubscription<T> subscription) {
    if (_onStartListen != null) {
      _onStartListen();
    }
  }

  void _onCancel(StreamSubscription<T> subscription) {
    if (_onAllCancel != null) {
      _onAllCancel();
    }
  }

  void add(T t) {
    _controller.add(t);
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
}

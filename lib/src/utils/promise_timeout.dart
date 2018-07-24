part of dslink.utils;

Future<T> awaitWithTimeout<T>(Future<T> future, int timeoutMs,
    Function onSuccessAfterTimeout, Function onErrorAfterTimeout) {
  Completer<T> completer = new Completer();

  Timer timer = new Timer(new Duration(milliseconds: timeoutMs), () {
    if (!completer.isCompleted) {
      completer.completeError(new Exception('Future timeout before complete'));
    }
  });
  future.then((T t) {
    if (completer.isCompleted) {
      onSuccessAfterTimeout(t);
    } else {
      timer.cancel();
      completer.complete(t);
    }
  }).catchError((err) {
    if (completer.isCompleted) {
      onErrorAfterTimeout(err);
    } else {
      timer.cancel();
      completer.completeError(err);
    }
  });

  return completer.future;
}

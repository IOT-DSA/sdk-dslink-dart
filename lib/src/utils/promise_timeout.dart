part of dslink.utils;

Future awaitWithTimeout(Future future, int timeoutMs,
    {Function onTimeout: null,
    Function onSuccessAfterTimeout: null,
    Function onErrorAfterTimeout: null}) {
  Completer completer = new Completer();

  Timer timer = new Timer(new Duration(milliseconds: timeoutMs), () {
    if (!completer.isCompleted) {
      if (onTimeout != null) {
        onTimeout();
      }
      completer.completeError(new Exception('Future timeout before complete'));
    }
  });
  future.then((t) {
    if (completer.isCompleted) {
      if (onSuccessAfterTimeout != null) {
        onSuccessAfterTimeout(t);
      }
    } else {
      timer.cancel();
      completer.complete(t);
    }
  }).catchError((err) {
    if (completer.isCompleted) {
      if (onErrorAfterTimeout != null) {
        onErrorAfterTimeout(err);
      }
    } else {
      timer.cancel();
      completer.completeError(err);
    }
  });

  return completer.future;
}

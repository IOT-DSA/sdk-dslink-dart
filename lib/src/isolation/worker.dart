part of dslink.isolation;

class _WorkerError {
  final dynamic errorEvent;
  final StackTrace stackTrace;
  
  _WorkerError(this.errorEvent, this.stackTrace);
}

class _WorkerData {
  final dynamic data;
  
  _WorkerData(this.data);
}

class _WorkerSendPort {
  final SendPort port;
  
  _WorkerSendPort(this.port);
}

class _WorkerStop {}

class _WorkerStopped {}

class WorkerSocket extends Stream<dynamic> implements StreamSink<dynamic> {
  final ReceivePort receiver;
  SendPort _sendPort;
  
  WorkerSocket.worker(SendPort port) : _sendPort = port, receiver = new ReceivePort(), isWorker = true {
    _sendPort.send(new _WorkerSendPort(receiver.sendPort));
    
    receiver.listen((msg) {
      if (msg is _WorkerData) {
        _controller.add(msg.data);
      } else if (msg is _WorkerError) {
        _controller.addError(msg.errorEvent, msg.stackTrace);
      } else if (msg is _WorkerStop) {
        _stopCompleter.complete();
        _sendPort.send(new _WorkerStopped());
      } else {
        throw new Exception("Unknown message: ${msg}");
      }
    });
  }
  
  final bool isWorker;
  
  bool get isMaster => !isWorker;
  
  Future waitFor() {
    if (isWorker) {
      throw new Future.value();
    } else {
      return _readyCompleter.future;
    }
  }
  
  Completer _readyCompleter = new Completer();
  
  WorkerSocket.master(this.receiver) : isWorker = false {
    receiver.listen((msg) {
      if (msg is _WorkerSendPort) {
        _sendPort = msg.port;
        _readyCompleter.complete();
      } else if (msg is _WorkerData) {
        _controller.add(msg.data);
      } else if (msg is _WorkerError) {
        _controller.addError(msg.errorEvent, msg.stackTrace);
      } else if (msg is _WorkerStopped) {
        _stopCompleter.complete();
      } else {
        throw new Exception("Unknown message: ${msg}");
      }
    });
  }
  
  @override
  void add(event) {
    _sendPort.send(new _WorkerData(event));
  }

  @override
  void addError(errorEvent, [StackTrace stackTrace]) {
    _sendPort.send(new _WorkerError(errorEvent, stackTrace));
  }

  @override
  Future addStream(Stream stream) {
    stream.listen((data) {
      add(data);
    });
    
    return new Future.value();
  }

  @override
  Future close() {
    _sendPort.send(new _WorkerStop());
    return _stopCompleter.future.then((_) {
      if (isMaster) {
        receiver.close();
      } else {
        new Future.delayed(new Duration(seconds: 1), () {
          receiver.close();
        });
      }
    });
  }

  @override
  Future get done => _stopCompleter.future;
  
  Completer _stopCompleter = new Completer();

  @override
  StreamSubscription listen(void onData(event), {Function onError, void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
  
  StreamController _controller = new StreamController();
}
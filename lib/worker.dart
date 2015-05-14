library dslink.worker;

import "dart:async";
import "dart:isolate";

typedef void WorkerFunction(Worker worker);
typedef Producer(input);

WorkerSocket createWorker(WorkerFunction function, {Map<String, dynamic> metadata}) {
  var receiver = new ReceivePort();
  Isolate.spawn(function, new Worker(receiver.sendPort, metadata));
  var socket = new WorkerSocket.master(receiver);
  return socket;
}

WorkerPool createWorkerPool(int count, WorkerFunction function, {Map<String, dynamic> metadata}) {
  var workers = [];
  for (var i = 1; i <= count; i++) {
    workers.add(createWorker(function, metadata: {
      "workerId": i
    }..addAll(metadata == null ? {} : metadata)));
  }
  return new WorkerPool(workers);
}

class WorkerPool {
  final List<WorkerSocket> sockets;

  WorkerPool(this.sockets);

  Future waitFor() {
    return Future.wait(sockets.map((it) => it.waitFor()).toList());
  }

  Future stop() {
    return Future.wait(sockets.map((it) => it.stop()).toList());
  }

  Future ping() {
    return Future.wait(sockets.map((it) => it.ping()).toList());
  }

  void send(dynamic data) {
    forEach((socket) => socket.send(data));
  }

  void listen(void handler(int worker, event)) {
    var i = 0;
    for (var worker in sockets) {
      var id = i;
      worker.listen((e) {
        handler(id, e);
      });
      i++;
    }
  }

  Future<WorkerPool> init() => Future.wait(sockets.map((it) => it.init()).toList()).then((_) => this);

  void forEach(void handler(WorkerSocket socket)) {
    sockets.forEach(handler);
  }

  void addMethod(String name, Producer handler) {
    forEach((socket) => socket.addMethod(name, handler));
  }

  Future<List<dynamic>> callMethod(String name, [argument]) {
    return Future.wait(sockets.map((it) => it.callMethod(name, argument)).toList());
  }

  WorkerSocket workerAt(int id) => sockets[id];
  WorkerSocket operator [](int id) => workerAt(id);
}

class _WorkerError {
  final dynamic errorEvent;
  final StackTrace stackTrace;

  _WorkerError(this.errorEvent, this.stackTrace);
}

class _WorkerRequest {
  final int id;
  final String name;
  final dynamic argument;

  _WorkerRequest(this.id, this.name, this.argument);
}

class _WorkerResponse {
  final int id;
  final String name;
  final dynamic value;

  _WorkerResponse(this.id, this.name, this.value);
}

class _WorkerData {
  final dynamic data;

  _WorkerData(this.data);
}

class Worker {
  final SendPort port;
  final Map<String, dynamic> metadata;

  Worker(this.port, [Map<String, dynamic> meta])
    : metadata = meta == null ? {} : meta;

  WorkerSocket createSocket() => new WorkerSocket.worker(port);
  Future<WorkerSocket> init() async => await createSocket().init();

  dynamic get(String key) => metadata[key];
  bool has(String key) => metadata.containsKey(key);
}

class _WorkerSendPort {
  final SendPort port;

  _WorkerSendPort(this.port);
}

class _WorkerStop {}

class _WorkerPing {
  final int id;

  _WorkerPing(this.id);
}

class _WorkerPong {
  final int id;

  _WorkerPong(this.id);
}

class _WorkerStopped {}

typedef Future<T> WorkerMethod<T>([argument]);

class WorkerSocket extends Stream<dynamic> implements StreamSink<dynamic> {
  final ReceivePort receiver;
  SendPort _sendPort;

  WorkerSocket.master(this.receiver) : isWorker = false {
    receiver.listen((msg) {
      if (msg is _WorkerSendPort) {
        _sendPort = msg.port;
        _readyCompleter.complete();
      } else if (msg is _WorkerData) {
        _controller.add(msg.data);
      } else if (msg is _WorkerError) {
        _controller.addError(msg.errorEvent, msg.stackTrace);
      } else if (msg is _WorkerPing) {
        _sendPort.send(new _WorkerPong(msg.id));
      } else if (msg is _WorkerPong) {
        if (_pings.containsKey(msg.id)) {
          _pings[msg.id].complete();
          _pings.remove(msg.id);
        }
      } else if (msg is _WorkerRequest) {
        _handleRequest(msg);
      } else if (msg is _WorkerResponse) {
        if (_responseHandlers.containsKey(msg.id)) {
          _responseHandlers.remove(msg.id).complete(msg.value);
        } else {
          throw new Exception("Invalid Request ID: ${msg.id}");
        }
      } else if (msg is _WorkerStopped) {
        _stopCompleter.complete();
      } else {
        throw new Exception("Unknown message: ${msg}");
      }
    });
  }

  WorkerSocket.worker(SendPort port)
  : _sendPort = port,
  receiver = new ReceivePort(),
  isWorker = true {
    _sendPort.send(new _WorkerSendPort(receiver.sendPort));

    receiver.listen((msg) {
      if (msg is _WorkerData) {
        _controller.add(msg.data);
      } else if (msg is _WorkerError) {
        _controller.addError(msg.errorEvent, msg.stackTrace);
      } else if (msg is _WorkerStop) {
        _stopCompleter.complete();
        _sendPort.send(new _WorkerStopped());
      } else if (msg is _WorkerPing) {
        _sendPort.send(new _WorkerPong(msg.id));
      } else if (msg is _WorkerPong) {
        if (_pings.containsKey(msg.id)) {
          _pings[msg.id].complete();
          _pings.remove(msg.id);
        }
      } else if (msg is _WorkerRequest) {
        _handleRequest(msg);
      } else if (msg is _WorkerResponse) {
        if (_responseHandlers.containsKey(msg.id)) {
          _responseHandlers.remove(msg.id).complete(msg.value);
        } else {
          throw new Exception("Invalid Request ID: ${msg.id}");
        }
      } else {
        throw new Exception("Unknown message: ${msg}");
      }
    });
  }

  Map<int, Completer> _pings = {};

  final bool isWorker;

  bool get isMaster => !isWorker;

  Future waitFor() {
    if (isWorker) {
      return new Future.value();
    } else {
      return _readyCompleter.future;
    }
  }

  Future<WorkerSocket> init() => waitFor().then((_) => this);

  void addMethod(String name, Producer producer) {
    _requestHandlers[name] = producer;
  }

  Future callMethod(String name, [argument]) {
    var completer = new Completer();
    _responseHandlers[_reqId] = completer;
    var req = new _WorkerRequest(_reqId, name, argument);
    _sendPort.send(req);
    _reqId++;
    return completer.future;
  }

  WorkerMethod<dynamic> getMethod(String name) => ([argument]) =>
  callMethod(name, argument);

  int _reqId = 0;

  void _handleRequest(_WorkerRequest req) {
    if (_requestHandlers.containsKey(req.name)) {
      var val = _requestHandlers[req.name](req.argument);
      new Future.value(val).then((result) {
        _sendPort.send(new _WorkerResponse(req.id, req.name, result));
      });
    } else {
      throw new Exception("Invalid Method: ${req.name}");
    }
  }

  Map<int, Completer> _responseHandlers = {};
  Map<String, Producer> _requestHandlers = {};

  Completer _readyCompleter = new Completer();

  int _pingId = 0;

  Future ping() {
    var completer = new Completer();
    _pings[_pingId] = completer;
    _sendPort.send(new _WorkerPing(_pingId));
    _pingId++;
    return completer.future;
  }

  @override
  void add(event) {
    _sendPort.send(new _WorkerData(event));
  }

  void send(event) => add(event);

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

  Future stop() => close();

  @override
  Future close() {
    _sendPort.send(new _WorkerStop());
    return _stopCompleter.future.then((_) {
      if (isMaster) {
        receiver.close();
      } else {
        return new Future.delayed(new Duration(seconds: 1), () {
          receiver.close();
        });
      }
    });
  }

  @override
  Future get done => _stopCompleter.future;

  Completer _stopCompleter = new Completer();

  @override
  StreamSubscription listen(void onData(event),
                            {Function onError, void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
    onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  StreamController _controller = new StreamController.broadcast();
}
/// Isolate Helpers
library dslink.isolation;

import "dart:io";
import "dart:isolate";
import "dart:async";
import "dart:math";

part "src/isolation/worker.dart";

typedef void WorkerFunction(port);

WorkerSocket createWorker(WorkerFunction function) {
  var receiver = new ReceivePort();
  Isolate.spawn(function, new Worker(receiver.sendPort));
  var socket = new WorkerSocket.master(receiver);
  return socket;
}

WorkerSocket createWorkerScript(String path) {
  var receiver = new ReceivePort();
  var file = new File(path);
  var uri = new Uri.file(file.path);
  Isolate.spawnUri(uri, [], new Worker(receiver.sendPort));
  var socket = new WorkerSocket.master(receiver);
  return socket;
}
/// Isolate Helpers
library dslink.isolation;

import "dart:isolate";
import "dart:async";

part "src/isolation/worker.dart";

typedef void WorkerFunction(port);

WorkerSocket spawnWorker(WorkerFunction function) {
  var receiver = new ReceivePort();
  Isolate.spawn(function, receiver.sendPort);
  var socket = new WorkerSocket.master(receiver);
  return socket;
}

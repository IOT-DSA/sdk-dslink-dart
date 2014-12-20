import "package:dslink/isolation.dart";
import "dart:isolate";

void _worker(port) {
  var socket = new WorkerSocket.worker(port);
  
  print("Worker Started.");
  
  socket.done.then((_) {
    print("Worker Stopped.");
  });
  
  socket.listen((data) {
    print("Worker Message: " + data);
  });
}

void main() {
  var receiver = new ReceivePort();
  var socket = new WorkerSocket.master(receiver);
  Isolate.spawn(_worker, receiver.sendPort);
  
  socket.waitFor().then((_) {
    socket.add("Hello World");
    socket.add("Goodbye World");
    return socket.close();
  });
}
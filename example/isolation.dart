import "package:dslink/isolation.dart";

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
  var socket = createWorker(_worker);
  
  socket.waitFor().then((_) {
    socket.add("Hello World");
    socket.add("Goodbye World");
    return socket.close();
  });
}
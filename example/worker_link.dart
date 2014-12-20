import "package:dslink/link.dart";
import "package:dslink/isolation.dart";
import "dart:async";

DSNode counterNode;
void main(args) {
  var link = new DSLink("DartIsolateLink", host: "rnd.iot-dsa.org", debug: args.contains("-d") || args.contains("--debug"));
  
  link.loadNodes([
    {
      "name": "Counter",
      "value": 0,
      "initialize": (node) => counterNode = node
    }
  ]);
  
  link.connect().then((_) {
    print("Connected.");
    _startWorker();
  });
}

void _startWorker() {
  var socket = createWorker(worker);
  
  socket.waitFor().then((_) {
    socket.listen((value) {
      counterNode.value = value;
    });
  });
}

void worker(port) {
  var socket = new WorkerSocket.worker(port);
  Timer timer;
  
  socket.done.then((_) {
    timer.cancel();
  });
  
  int i = 0;
  
  timer = new Timer.periodic(new Duration(seconds: 1), (_) {
    i++;
    socket.add(i);
  });
}
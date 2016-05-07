import "package:dslink/utils.dart" show Scheduler;
import "package:dslink/worker.dart";

main(List<String> args, message) async {
  Worker worker = buildWorkerForScript(message as Map<String, dynamic>);
  WorkerSocket socket = await worker.init(methods: {
    "hello": (_) => print("Hello World")
  });

  print("Worker Started");

  Scheduler.after(new Duration(seconds: 2), () {
    socket.callMethod("stop");
  });
}

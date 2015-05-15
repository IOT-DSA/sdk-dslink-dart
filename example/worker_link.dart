import "package:dslink/dslink.dart";
import "package:dslink/worker.dart";

LinkProvider link;

main(List<String> args) async {
  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "CounterWorker-", defaultNodes: {
    "Counter": {
      r"$type": "number", // The type of the node is a number.
      r"$writable": "write", // This node's value can be set by a requester.
      "?value": 0 // The default counter value.
    }
  }, encodePrettyJson: true);

  // Connect to the broker.
  link.connect();

  SimpleNode counterNode = link["/Counter"];
  counterNode.subscribe((update) => link.save());

  WorkerSocket worker = await createWorker(counterWorker).init();
  worker.addMethod("increment", (_) {
    counterNode.updateValue((counterNode.lastValueUpdate.value as int) + 1);
  });
}

counterWorker(Worker worker) async {
  WorkerSocket socket = await worker.init();
  Scheduler.every(Interval.ONE_SECOND, () async {
    await socket.callMethod("increment");
  });
}

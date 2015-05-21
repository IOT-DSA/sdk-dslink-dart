import "package:dslink/dslink.dart";
import "package:dslink/worker.dart";

int workers = 30; // Number of Workers

main() async {
  WorkerPool pool = createWorkerPool(workers, linkWorker); // Create a Worker Pool
  await pool.init(); // Initialize the Worker Pool
  await pool.divide("spawn", 3000); // Divide 3000 calls to "spawn" over all the workers, which is 100 links per worker.
}

linkWorker(Worker worker) async {
  spawnLink(int i) async {
    LinkProvider link = new LinkProvider([], "Worker-${i}-", defaultNodes: { // Create a Link Provider
      "String_Value": { // Just a value so that things aren't empty.
        r"$name": "String Value",
        r"$type": "string",
        "?value": "Hello World"
      }
    });

    link.configure(); // Configure the Link
    link.init(); // Initialize the Link
    link.connect(); // Connect to the Broker
  }

  await worker.init(methods: { // Initialize the Worker, and add a "spawn" method.
    "spawn": (i) {
      spawnLink(i);
    }
  });
}

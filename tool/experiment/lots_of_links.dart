import "package:dslink/dslink.dart";
import "package:dslink/worker.dart";

int workers = 20; // Number of Workers

main() async {
  WorkerPool pool = createWorkerPool(workers, linkWorker); // Create a Worker Pool
  await pool.init(); // Initialize the Worker Pool
  await pool.divide("spawn", 1000); // Divide 1000 calls to "spawn" over all the workers, which is 50 links per worker.
}

linkWorker(Worker worker) async {
  spawnLink(int i) async {
    updateLogLevel("OFF");
    LinkProvider link = new LinkProvider([], "Worker-${i}-", defaultNodes: { // Create a Link Provider
      "string": { // Just a value so that things aren't empty.
        r"$name": "String Value",
        r"$type": "string",
        "?value": "Hello World"
      }
    }, autoInitialize: false);

    link.configure(); // Configure the Link
    link.init(); // Initialize the Link
    link.connect().then((_) {
      print("Link #${i} Connected.");
    }); // Connect to the Broker
  }

  await worker.init(methods: { // Initialize the Worker, and add a "spawn" method.
    "spawn": (i) {
      spawnLink(i);
    }
  });
}

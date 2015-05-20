import "package:dslink/dslink.dart";
import "package:dslink/worker.dart";

int workers = 25;

main() async {
  WorkerPool pool = createWorkerPool(workers, linkWorker);
  await pool.init();
  var result = await pool.divide("spawn", 2000);
}

linkWorker(Worker worker) async {
  spawnLink(int i) async {
    LinkProvider link = new LinkProvider([], "Worker-${i}-", defaultNodes: {
      "String_Value": {
        r"$name": "String Value",
        r"$type": "string",
        "?value": "Hello World"
      }
    });

    link.configure();
    link.init();
    link.connect();
  }

  await worker.init(methods: {
    "spawn": (i) {
      spawnLink(i);
    }
  });
}

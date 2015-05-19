import "package:dslink/worker.dart";

int workers = 25;

main() async {
  WorkerPool pool = createWorkerPool(workers, calculateWorker);
  await pool.init();
  var result = await pool.divide("calculate", 500);
  print(result);
  await pool.stop();
}

calculateWorker(Worker worker) async {
  await worker.init(methods: {
    "calculate": (i) => i * 2
  });
}

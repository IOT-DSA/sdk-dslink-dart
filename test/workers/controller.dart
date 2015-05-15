import "package:dslink/worker.dart";

main() async {
  WorkerSocket worker;
  worker = await createWorkerScript("worker.dart").init(methods: {
    "stop": (_) => worker.stop()
  });
  await worker.callMethod("hello");
}

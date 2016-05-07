library dslink.test.workers;

import "package:test/test.dart";
import "package:dslink/worker.dart";

void main() {
  group("Function Worker", () {
    workerTests((m, [x]) => createWorker(m, metadata: x));
  });
}

void workerTests(WorkerSocket factory(WorkerFunction func, [Map<String, dynamic> metadata])) {
  test("calls a simple method that returns a result", () async {
    for (int i = 1; i <= 10; i++) {
      WorkerSocket socket = await factory(transformStringWorker).init();

      try {
        for (int x = 1; x <= 5; x++) {
          var result = await socket.callMethod("transform", "Hello World")
            .timeout(const Duration(seconds: 3), onTimeout: () => null);

          expect(result, equals("hello world"));
        }
      } finally {
        await socket.close();
      }
    }
  });
}

transformStringWorker(Worker worker) async {
  await worker.init(methods: {
    "transform": (String input) => input.toLowerCase()
  });
}

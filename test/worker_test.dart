@TestOn("vm")
library dslink.test.workers;

import "dart:async";

import "package:test/test.dart";
import "package:dslink/worker.dart";

void main() {
  group("Function Worker", () {
    workerTests((m, [x]) => createWorker(m, metadata: x));
  });
}

void workerTests(WorkerSocket factory(WorkerFunction func, [Map<String, dynamic> metadata])) {
  test("receives a message", () async {
    WorkerSocket socket = await factory(receiveMessageWorker).init();

    try {
      Timer.run(() {
        socket.add("Hello World");
      });
      var result = await socket.first.timeout(new Duration(milliseconds: 250), onTimeout: () => null);

      expect(result, isNotNull, reason: "Worker should have sent the message back.");
    } finally {
      await socket.close();
    }
  });
}

receiveMessageWorker(Worker worker) async {
  WorkerSocket socket = await worker.init();
  socket.add(await socket.first);
}

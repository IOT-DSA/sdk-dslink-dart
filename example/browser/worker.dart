import "package:dslink/worker.dart";

main() async {
  var worker = await createWorker(transformStringWorker).init();
  print(await worker.callMethod("transform", "Hello World"));
}

transformStringWorker(Worker worker) async {
  await worker.init(methods: {
    "transform": (String input) => input.toLowerCase()
  });
}

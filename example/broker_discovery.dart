import "package:dslink/broker.dart";

main() async {
  var client = new BrokerDiscoveryClient();

  await client.init();
  client.discover().listen((url) {
    print("Discovered Broker at ${url}");
  });
}

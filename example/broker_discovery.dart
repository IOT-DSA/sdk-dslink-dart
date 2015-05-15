import "package:dslink/dslink.dart";

main() async {
  var client = new BrokerDiscoveryClient();

  await client.init();

  await for (var url in client.discover()) {
    print("Discovered Broker at ${url}");
  }
}

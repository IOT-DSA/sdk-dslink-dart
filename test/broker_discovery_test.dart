@TestOn("vm")
@Timeout(const Duration(seconds: 10))
library dslink.test.vm.discovery;

import "package:dslink/broker.dart" show BrokerDiscoveryClient, BrokerDiscoverRequest;

import "package:test/test.dart";

main() => group("Broker Discovery", brokerDiscoveryTests);

brokerDiscoveryTests() {
  test("works with a single broker", () async {
    var host = new BrokerDiscoveryClient();
    await host.init(true);
    host.requests.listen((request) {
      request.reply("http://127.0.0.1:8080");
    });

    var client = new BrokerDiscoveryClient();
    await client.init();
    var urls = await client.discover().toList();
    expect(urls.length, equals(1));
    expect(urls.first, equals("http://127.0.0.1:8080"));
    await host.close();
    await client.close();
  }, skip: true);
}

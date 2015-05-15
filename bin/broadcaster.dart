import "dart:io";

import "package:args/args.dart";

import "package:dslink/broker.dart" show BrokerDiscoveryClient, BrokerDiscoverRequest;

main(List<String> args) async {
  var argp = new ArgParser(allowTrailingOptions: true);
  var discovery = new BrokerDiscoveryClient();

  argp.addFlag("help", abbr: "h", help: "Display Help Message", negatable: false);

  var opts = argp.parse(args);

  if (opts["help"] || opts.rest.isEmpty) {
    print("Usage: broadcaster <URLs...>");
    if (argp.usage.isNotEmpty) {
      print(argp.usage);
    }
    exit(1);
  }

  try {
    await discovery.init(true);
    discovery.requests.listen((BrokerDiscoverRequest request) {
      for (var url in opts.rest) {
        request.reply(url);
      }
    });
  } catch (e) {
    print("Error: Failed to start broadcast service. Are you running another broadcaster or broker on this machine?");
    exit(1);
  }

  print("Broadcasting Service Started.");
}

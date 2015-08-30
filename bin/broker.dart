import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dslink/broker.dart";
import "package:dslink/client.dart";
import "package:dslink/utils.dart";
import "package:dslink/server.dart";

BrokerNodeProvider broker;
DsHttpServer server;
LinkProvider link;
BrokerDiscoveryClient discovery;

const Map<String, String> VARS = const {
  "BROKER_URL": "broker_url",
  "BROKER_LINK_PREFIX": "link_prefix",
  "BROKER_PORT": "port",
  "BROKER_HOST": "host",
  "BROKER_HTTPS_PORT": "https_port",
  "BROKER_CERTIFICATE_NAME": "certificate_name",
  "BROKER_BROADCAST": "broadcast",
  "BROKER_BROADCAST_URL": "broadcast_url"
};

Future<String> getNetworkAddress() async {
  List<NetworkInterface> interfaces = await NetworkInterface.list();
  if (interfaces == null || interfaces.isEmpty) {
    return null;
  }
  NetworkInterface interface = interfaces.first;
  List<InternetAddress> addresses = interface.addresses
      .where((it) => !it.isLinkLocal && !it.isLoopback)
      .toList();
  if (addresses.isEmpty) {
    return null;
  }
  return addresses.first.address;
}

main(List<String> _args) async {
  var args = new List<String>.from(_args);
  var configFile = new File("broker.json");
  var https = false;

  if (args.contains("--docker")) {
    args.remove("--docker");
    var config = {
      "host": "0.0.0.0",
      "port": 8080,
      "link_prefix": "broker-",
      "broadcast": true
    };

    VARS.forEach((n, c) {
      if (Platform.environment.containsKey(n)) {
        var v = Platform.environment[n];
        if (v == "true" || v == "false") {
          v = v == "true";
        }

        var number = num.parse(v, (_) => null);

        if (number != null) {
          v = number;
        }

        config[c] = v;
      }
    });

    await configFile.writeAsString(JSON.encode(config));
  }

  if (!(await configFile.exists())) {
    await configFile.create(recursive: true);
    await configFile.writeAsString(defaultConfig);
  }

  var config = JSON.decode(await configFile.readAsString());

  dynamic getConfig(String key, [defaultValue]) {
    if (!config.containsKey(key)) {
      return defaultValue;
    }
    return config[key];
  }

  saveConfig() async {
    var data = new JsonEncoder.withIndent("  ").convert(config);
    await configFile.writeAsString(data + '\n');
  }

  updateLogLevel(getConfig("log_level", "info"));
  broker = new BrokerNodeProvider();
  server = new DsHttpServer.start(getConfig("host", "0.0.0.0"),
      httpPort: getConfig("port", -1),
      httpsPort: getConfig("https_port", -1),
      certificateName: getConfig("certificate_name"),
      nodeProvider: broker,
      linkManager: broker);

  https = getConfig("https_port", -1) != -1;

  if (getConfig("broker_url") != null) {
    var url = getConfig("broker_url");
    args.addAll(["--broker", url]);
  }

  if (args.any((it) => it.startsWith("--broker")) || args.contains("-b")) {
    link = new LinkProvider(args, getConfig("link_prefix", "broker-"),
        provider: broker)..connect();
  }

  if (getConfig("broadcast", false)) {
    var addr = await getNetworkAddress();
    var scheme = https ? "https" : "http";
    var port = https ? getConfig("https_port") : getConfig("port");
    var url = getConfig("broadcast_url", "${scheme}://${addr}:${port}/conn");
    print("Starting Broadcast of Broker at ${url}");
    discovery = new BrokerDiscoveryClient();
    try {
      await discovery.init(true);
      discovery.requests.listen((BrokerDiscoverRequest request) {
        request.reply(url);
      });
    } catch (e) {
      print(
          "Warning: Failed to start broker broadcast service. Are you running more than one broker on this machine?");
    }
  }

  if (getConfig("upstream") != null) {
    broker.done.then((_) {
      Map<String, Map<String, dynamic>> upstream = getConfig("upstream", {});

      for (var name in upstream.keys) {
        var url = upstream[name]["url"];
        var ourName = upstream[name]["name"];
        var enabled = upstream[name]["enabled"];
        broker.upstream.addUpstreamConnection(name, url, ourName, enabled);
      }
    });
  }

  String lastUpstreamConns = "";

  new Timer.periodic(const Duration(seconds: 5), (_) async {
    var map = broker.upstream.getConfigMap();
    var x = JSON.encode(map);

    if (lastUpstreamConns.isNotEmpty || (x != lastUpstreamConns)) {
      lastUpstreamConns = x;

      config["upstream"] = map;
      await saveConfig();
    }
  });
}

const String defaultConfig = """{
  "host": "0.0.0.0",
  "port": 8080,
  "link_prefix": "broker-"
}
""";

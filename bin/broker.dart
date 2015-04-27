import "dart:io";
import "dart:convert";

import "package:dslink/broker.dart";
import "package:dslink/client.dart";
import "package:dslink/server.dart";

LinkProvider link;

main(List<String> args) async {
  File configFile = new File("broker.json");
  if (!configFile.existsSync()) {
    configFile.createSync(recursive: true);
    configFile.writeAsStringSync(defaultConfig);
  }

  var config = JSON.decode(configFile.readAsStringSync());

  dynamic getConfig(String key, [defaultValue]) {
    if (!config.containsKey(key)) {
      return defaultValue;
    }
    return config[key];
  }

  var broker = new BrokerNodeProvider();
  var server = new DsHttpServer.start(getConfig("host", "0.0.0.0"), httpPort: getConfig("port", -1),
    httpsPort: getConfig("https_port", -1),
    certificateName: getConfig("certificate_name"), nodeProvider: broker, linkManager: broker);

  if (args.any((it) => it.startsWith("--broker")) || args.contains("-b")) {
    link = new LinkProvider(args, getConfig("link_prefix", "broker-"), nodeProvider: broker)..connect();
  }
}

const String defaultConfig = """{
  "host": "0.0.0.0",
  "port": 8080,
  "link_prefix": "broker-"
}
""";

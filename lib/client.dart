library dslink.client;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

import 'common.dart';
import 'requester.dart';
import 'responder.dart';
import 'utils.dart';
import 'src/crypto/pk.dart';
import 'src/http/websocket_conn.dart';

import "package:logging/logging.dart";

import "package:dslink/broker.dart" show BrokerDiscoveryClient;

export 'src/crypto/pk.dart';

part 'src/http/client_link.dart';
part 'src/http/client_http_conn.dart';

class LinkProvider {
  HttpClientLink link;
  SimpleNodeProvider provider;
  PrivateKey prikey;
  String brokerUrl;
  File _nodesFile;
  String prefix;
  List<String> args;
  bool isRequester = false;
  String command = 'link';
  bool isResponder = true;
  Map defaultNodes;
  Map profiles;
  NodeProvider nodeProvider;
  bool enableHttp = false;
  bool encodePrettyJson = false;
  bool strictOptions = false;
  bool exitOnFailure = true;

  LinkProvider(
    this.args,
    this.prefix,
    {
      this.isRequester: false,
      this.command: 'link',
      this.isResponder: true,
      this.defaultNodes,
      this.profiles,
      this.provider,
      this.nodeProvider,
      this.enableHttp: false,
      this.encodePrettyJson: false,
      bool autoInitialize: true,
      this.strictOptions: false,
      this.exitOnFailure: true
    }) {
    if (autoInitialize) {
      configure();
      init();
    }
  }

  bool _configured = false;

  void configure() {
    _configured = true;

    if (link != null) {
      link.close();
      link = null;
    }

    ArgParser argp = new ArgParser(allowTrailingOptions: !strictOptions);
    argp.addOption("broker", abbr: 'b', help: "Broker URL");
    argp.addOption("name", abbr: 'n', help: "Link Name");
    argp.addOption("log", abbr: "l", allowed: Level.LEVELS.map((it) => it.name).toList(), help: "Log Level", defaultsTo: "INFO");
    argp.addFlag("help", abbr: "h", help: "Displays this Help Message");
    argp.addFlag("discover", abbr: "d", help: "Automatically Discover a Broker", negatable: false);

    if (args.length == 0) {
      // default
      args = ["-b", "localhost:8080/conn", "--log", "INFO"];
      try {
        assert(false);
      } catch (e) {
        // in debug mode, turn on logging for everything
        args[3] = "ALL";
      }
    }

    ArgResults opts = argp.parse(args);

    updateLogLevel(opts["log"]);

    String helpStr = 'usage: $command [--broker URL] [--log LEVEL] [--name NAME]';

    if (opts['help'] == true) {
      print(helpStr);
      print(argp.usage);
      if (exitOnFailure) {
        exit(1);
      } else {
        return;
      }
    }

    brokerUrl = opts['broker'];
    if (brokerUrl == null && !opts["discover"]) {
      print(helpStr);
      return;
    }

    String name = opts['name'];

    if (name != null) {
      if (name.endsWith('-')) {
        prefix = name;
      } else {
        prefix = '${name}-';
      }
    }

    // load configs
    File dslinkFile = new File.fromUri(Uri.parse('dslink.json'));

    if (dslinkFile.existsSync()) {
      var e;
      try {
        String configStr = dslinkFile.readAsStringSync();
        dslinkJson = DsJson.decode(configStr);
      } catch (err) {
        e = err;
      }

      if (dslinkJson == null) {
        logger.severe("Invalid dslink.json", e);
        return;
      }
    } else {
      dslinkJson = {};
    }

    if (brokerUrl != null) {
      if (!brokerUrl.startsWith('http')) {
        brokerUrl = 'http://$brokerUrl';
      }
    }

    File keyFile = getConfig('key') == null ? new File(".dslink.key") : new File.fromUri(Uri.parse(getConfig('key')));
    String key;

    try {
      key = keyFile.readAsStringSync();
      prikey = new PrivateKey.loadFromString(key);
    } catch (err) {
    }

    if (key == null || key.length != 131) {
      // 43 bytes d, 87 bytes Q, 1 space
      // generate the key
      String macs;
      if (Platform.isWindows) {
        macs = Process.runSync('getmac', []).stdout.toString();
      } else {
        try {
          macs = Process.runSync('arp', ['-an']).stdout.toString();
        } catch (e) {
          macs = Process.runSync('ifconfig', []).stdout.toString();
        }
      }
      // randomize the PRNG with the system mac (as well as timestamp)
      DSRandom.instance.randomize(macs);
      prikey = new PrivateKey.generate();
      key = prikey.saveToString();
      keyFile.writeAsStringSync(key);
    }

    if (opts["discover"]) {
      _discoverBroker = true;
    }
  }

  bool _discoverBroker = false;

  void init() {
    if (!_configured) {
      configure();
    }

    if (nodeProvider == null) {
      provider = new SimpleNodeProvider(null, profiles);
      nodeProvider = provider;
      _nodesFile = getConfig('nodes') == null ? new File("nodes.json") : new File.fromUri(Uri.parse(getConfig('nodes')));
      Map loadedNodesData;

      try {
        String nodesStr = _nodesFile.readAsStringSync();
        loadedNodesData = DsJson.decode(nodesStr);
      } catch (err) {
      }

      if (loadedNodesData != null) {
        provider.init(loadedNodesData);
      } else if (defaultNodes != null) {
        provider.init(defaultNodes);
      }
    }

    void doRun() {
      link = new HttpClientLink(
          brokerUrl,
          prefix,
          prikey,
          isRequester: isRequester,
          isResponder: isResponder,
          nodeProvider: nodeProvider,
          enableHttp: enableHttp
      );
      _ready = true;

      if (_connectOnReady) {
        connect();
      }
    }

    if (_discoverBroker) {
      var discovery = new BrokerDiscoveryClient();
      new Future(() async {
        await discovery.init();
        try {
          var broker = await discovery.discover().first;
          print("Discovered Broker at ${broker}");
          brokerUrl = broker;
          doRun();
        } catch (e) {
          print("Failed to discover a broker.");
          exit(1);
        }
      });
    } else {
      doRun();
    }
  }

  Map dslinkJson;

  /// Gets a configuration from the dslink.json
  Object getConfig(String key) {
    if (dslinkJson != null &&
      dslinkJson['configs'] is Map &&
      dslinkJson['configs'][key] is Map &&
      dslinkJson['configs'][key].containsKey('value')) {
      return dslinkJson['configs'][key]['value'];
    }
    return null;
  }

  bool _ready = false;
  bool _connectOnReady = false;

  void connect() {
    if (_ready) {
      if (link != null) link.connect();
    } else {
      _connectOnReady = true;
    }
  }

  Requester get requester => link.requester;

  Future<Requester> get onRequesterReady => link.onRequesterReady;

  void close() {
    if (link != null) {
      link.close();
      link = null;
    }
  }

  void stop() => close();

  bool get didInitializationFail => link == null;
  bool get isInitialized => link != null;

  void save() {
    if (_nodesFile != null && provider != null) {
      _nodesFile.writeAsStringSync(DsJson.encode(provider.save(), pretty: encodePrettyJson));
    }
  }

  LocalNode getNode(String path) {
    return provider.getNode(path);
  }

  LocalNode addNode(String path, Map m) {
    return provider.addNode(path, m);
  }

  void removeNode(String path) {
    provider.removeNode(path);
  }

  void updateValue(String path, dynamic value) {
    provider.updateValue(path, value);
  }

  LocalNode operator [](String path) => provider[path];
}

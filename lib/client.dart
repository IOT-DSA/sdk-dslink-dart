/// Provides the base APIs for the DSLink SDK on the Dart VM.
library dslink.client;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:args/args.dart';

import 'common.dart';
import 'requester.dart';
import 'responder.dart';
import 'utils.dart';
import 'src/crypto/pk.dart';
import 'src/http/websocket_conn.dart';

import "package:logging/logging.dart";

import "package:dslink/broker.dart" show BrokerDiscoveryClient;

export "src/crypto/pk.dart";

part 'src/http/client_link.dart';
//part 'src/http/client_http_conn.dart';

/// A Handler for Argument Results
typedef void OptionResultsHandler(ArgResults results);

/// Main Entry Point for DSLinks on the Dart VM
class LinkProvider {
  static bool _hasExitListener = false;

  /// The Link Object
  HttpClientLink link;

  /// The Node Provider
  NodeProvider provider;

  /// The Private Key
  PrivateKey privateKey;

  /// The Broker URL
  String brokerUrl;
  File _nodesFile;

  /// The Link Name
  String prefix;

  /// The Command-line Arguments
  List<String> args;

  /// Are we a requester?
  bool isRequester = false;

  /// The Command Name
  String command = 'link';

  /// Are we a responder?
  bool isResponder = true;

  /// Default Nodes
  Map defaultNodes;

  /// Profiles
  Map profiles;

  /// Enable HTTP Fallback?
  bool enableHttp = true;

  /// Encode Pretty JSON?
  bool encodePrettyJson = false;

  /// Strict Options?
  bool strictOptions = false;

  /// Exit on Failure?
  bool exitOnFailure = true;

  /// Load the nodes.json?
  bool loadNodesJson = true;

  /// Default Log Level.
  String defaultLogLevel = "INFO";

  /// Create a Link Provider.
  /// [args] are the command-line arguments to pass in.
  /// [prefix] is the link name.
  /// [isRequester] specifies if you are a requester or not.
  /// [isResponder] specifies if you a responder or not.
  /// [command] is the command name for this link.
  /// [defaultNodes] specify the default nodes to initialize if a nodes.json is not present.
  /// [profiles] specify the profiles for this link.
  /// [provider] is a node provider. If it is not specified, one will be created for you.
  /// [enableHttp] toggles whether to enable HTTP fallbacks.
  /// [encodePrettyJson] specifies whether to encode pretty JSON files when writing the nodes.json
  /// [autoInitialize] specifies whether to initialize the link inside the constructor.
  /// [strictOptions] toggles allowing trailing options in the argument parser.
  /// [exitOnFailure] toggles exiting when the link fails.
  /// [loadNodesJson] specifies whether to load the nodes.json file or not.
  /// [defaultLogLevel] specifies the default log level.
  /// [nodeProvider] is the same as [provider]. It is provided for backwards compatibility.
  LinkProvider(this.args, this.prefix,
      {this.isRequester: false,
      this.command: 'link',
      this.isResponder: true,
      this.defaultNodes,
      this.profiles,
      this.provider,
      this.enableHttp: true,
      this.encodePrettyJson: false,
      bool autoInitialize: true,
      this.strictOptions: false,
      this.exitOnFailure: true,
      this.loadNodesJson: true,
      this.defaultLogLevel: "INFO",
      NodeProvider nodeProvider // For Backwards Compatibility
      }) {
    exitOnFailure = !(const bool.fromEnvironment("dslink.runtime.manager", defaultValue: false));

    if (nodeProvider != null) {
      provider = nodeProvider;
    }

    if (autoInitialize) {
      init();
    }

    if (!_hasExitListener) {
      _hasExitListener = true;
      try {
        var rp = new ReceivePort();
        Isolate.current.addOnExitListener(rp.sendPort);
        rp.listen((e) {
          try {
            rp.close();
            close();
          } catch (e) {}
        });
      } catch (e) {}
    }
  }

  String _basePath = ".";

  bool _configured = false;

  /// Configure the link.
  /// If [argp] is provided for argument parsing, it is used.
  /// This includes:
  /// - processing command-line arguments
  /// - setting broker urls
  /// - loading dslink.json files
  /// - loading or creating private keys
  bool configure({ArgParser argp, OptionResultsHandler optionsHandler}) {
    _configured = true;

    if (link != null) {
      link.close();
      link = null;
    }

    if (argp == null) {
      argp = new ArgParser(allowTrailingOptions: !strictOptions);
    }

    argp.addOption("broker",
        abbr: "b",
        help: "Broker URL",
        defaultsTo: "http://127.0.0.1:8080/conn");
    argp.addOption("name", abbr: "n", help: "Link Name");
    argp.addOption("base-path", help: "Base Path for DSLink");
    argp.addOption("log",
        abbr: "l",
        allowed: Level.LEVELS.map((it) => it.name.toLowerCase()).toList()
          ..addAll(["auto", "debug"]),
        help: "Log Level",
        defaultsTo: "AUTO");
    argp.addFlag("help",
        abbr: "h", help: "Displays this Help Message", negatable: false);
    argp.addFlag("discover",
        abbr: "d", help: "Automatically Discover a Broker", negatable: false);

    ArgResults opts = argp.parse(args);

    if (opts["log"] == "auto") {
      if (DEBUG_MODE) {
        updateLogLevel("all");
      } else {
        updateLogLevel(defaultLogLevel);
      }
    } else {
      updateLogLevel(opts["log"]);
    }

    if (opts["base-path"] != null) {
      _basePath = opts["base-path"];

      if (_basePath.endsWith("/")) {
        _basePath = _basePath.substring(0, _basePath.length - 1);
      }
    }

    String helpStr =
        "usage: $command [--broker URL] [--log LEVEL] [--name NAME] [--discover]";

    if (opts["help"]) {
      print(helpStr);
      print(argp.usage);
      if (exitOnFailure) {
        exit(1);
      } else {
        return false;
      }
    }

    brokerUrl = opts['broker'];
    if (brokerUrl == null && !opts["discover"]) {
      print(
          "No Broker URL Specified. One of [--broker, --discover] is required.");
      print(helpStr);
      print(argp.usage);
      if (exitOnFailure) {
        exit(1);
      } else {
        return false;
      }
    }

    String name = opts["name"];

    if (name != null) {
      if (name.endsWith("-")) {
        prefix = name;
      } else {
        prefix = "${name}-";
      }
    }

    // load configs
    File dslinkFile = new File("${_basePath}/dslink.json");

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
        if (exitOnFailure) {
          exit(1);
        } else {
          return false;
        }
      }
    } else {
      dslinkJson = {};
    }

    if (brokerUrl != null) {
      if (!brokerUrl.startsWith('http')) {
        brokerUrl = 'http://$brokerUrl';
      }
    }

    Uri brokerUri = Uri.parse(brokerUrl);

    File keyFile = getConfig('key') == null
        ? new File("${_basePath}/.dslink.key")
        : new File.fromUri(Uri.parse(getConfig('key')));
    String key;

    try {
      key = keyFile.readAsStringSync();
      privateKey = new PrivateKey.loadFromString(key);
    } catch (err) {}

    if (key == null || key.length != 131) {
      // 43 bytes d, 87 bytes Q, 1 space
      // generate the key
      if(DSRandom.instance.needsEntropy) {
        String macs;
        if (Platform.isWindows) {
          macs = Process.runSync("getmac", []).stdout.toString();
        } else {
          try {
            macs = Process.runSync("arp", ["-an"]).stdout.toString();
          } catch (e) {
            macs = Process.runSync("ifconfig", []).stdout.toString();
          }
        }
        // randomize the PRNG with the system mac (as well as timestamp)
        DSRandom.instance.addEntropy(macs);
      }
      privateKey = new PrivateKey.generateSync();
      key = privateKey.saveToString();
      keyFile.writeAsStringSync(key);
    }

    if (opts["discover"]) {
      _discoverBroker = true;
    }

    if (optionsHandler != null) {
      optionsHandler(opts);
    }

    return true;
  }

  /// A Method that a Custom Link Provider can override for changing how to choose a broker.
  /// By default this selects the first broker available.
  Future<String> chooseBroker(Stream<String> brokers) async {
    return await brokers.first;
  }

  bool _discoverBroker = false;

  /// Retrieves a Broadcast Stream which subscribes to [path] with the specified [cacheLevel].
  /// The node is only subscribed if there is at least one stream subscription.
  /// When the stream subscription count goes to 0, the node is unsubscribed from.
  Stream<ValueUpdate> onValueChange(String path, {int cacheLevel: 1}) {
    RespSubscribeListener listener;
    StreamController<ValueUpdate> controller;
    int subs = 0;
    controller = new StreamController<ValueUpdate>.broadcast(onListen: () {
      subs++;
      if (listener == null) {
        listener = this[path].subscribe((ValueUpdate update) {
          controller.add(update);
        }, cacheLevel);
      }
    }, onCancel: () {
      subs--;
      if (subs == 0) {
        listener.cancel();
        listener = null;
      }
    });
    return controller.stream;
  }

  /// Gets the value for [path] and forcibly updates the value to the same exact value.
  void syncValue(String path) {
    var n = this[path];
    n.updateValue(n.lastValueUpdate.value, force: true);
  }

  bool _reconnecting = false;

  /// Initializes the Link.
  /// There is no guarantee that the link will be ready when this method returns.
  /// If the [configure] method is not called prior to calling this method, it is called.
  ///
  /// This method handles the following:
  /// - calling [configure] if it has not been called.
  /// - creating a [provider] if it has not been created.
  /// - loading the nodes.json file.
  /// - creating the actual link.
  /// - discovering brokers if that was enabled.
  void init() {
    if (!_configured) {
      if (!configure()) {
        return;
      }
    }

    _initialized = true;

    if (provider == null) {
      provider = new SimpleNodeProvider(null, profiles);
    }

    if (loadNodesJson &&
        provider is SerializableNodeProvider &&
        !_reconnecting) {
      _nodesFile = getConfig('nodes') == null
          ? new File("${_basePath}/nodes.json")
          : new File.fromUri(Uri.parse(getConfig('nodes')));
      Map loadedNodesData;

      try {
        String nodesStr = _nodesFile.readAsStringSync();
        loadedNodesData = DsJson.decode(nodesStr);
      } catch (err) {}

      if (loadedNodesData != null) {
        (provider as SerializableNodeProvider).init(loadedNodesData);
      } else if (defaultNodes != null) {
        (provider as SerializableNodeProvider).init(defaultNodes);
      }
    }

    void doRun() {
      link = new HttpClientLink(brokerUrl, prefix, privateKey,
          isRequester: isRequester,
          isResponder: isResponder,
          nodeProvider: provider,
          enableHttp: enableHttp);
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
          var broker = await chooseBroker(discovery.discover());
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

  /// The dslink.json contents. This is only available after [configure] is called.
  Map dslinkJson;

  /// Gets a configuration value from the dslink.json
  Object getConfig(String key) {
    if (dslinkJson != null &&
        dslinkJson['configs'] is Map &&
        dslinkJson['configs'][key] is Map &&
        dslinkJson['configs'][key].containsKey('value')) {
      return dslinkJson['configs'][key]['value'];
    }
    return null;
  }

  bool _initialized = false;
  bool _ready = false;
  bool _connectOnReady = false;

  /// Connects the link to the broker.
  Future connect() {
    if (_connectedCompleter == null) {
      _connectedCompleter = new Completer();
    }

    if (!_configured || !_initialized) {
      init();
    }

    if (_ready) {
      link.onConnected.then(_connectedCompleter.complete);
      if (link != null) link.connect();
    } else {
      _connectOnReady = true;
    }
    return _connectedCompleter.future;
  }

  Completer _connectedCompleter;

  /// The requester object.
  Requester get requester => link.requester;

  /// Completes when the requester is ready for use.
  Future<Requester> get onRequesterReady => link.onRequesterReady;

  /// Closes the link by disconnecting from the broker.
  /// You can call [connect] again once you have closed a link.
  void close() {
    _connectedCompleter = null;
    if (link != null) {
      link.close();
      link = null;
      _initialized = false;
      _reconnecting = true;
    }
  }

  /// An alias to [close].
  void stop() => close();

  /// Checks if the link object is null.
  bool get didInitializationFail => link == null;

  /// Checks if the link object is not null.
  bool get isInitialized => link != null;

  /// Synchronously saves the nodes.json file.
  void save() {
    if (_nodesFile != null && provider != null) {
      if (provider is! SerializableNodeProvider) {
        return;
      }

      _nodesFile.writeAsStringSync(DsJson.encode(
          (provider as SerializableNodeProvider).save(),
          pretty: encodePrettyJson));
    }
  }

  /// Asynchronously saves the nodes.json file.
  Future saveAsync() async {
    if (_nodesFile != null && provider != null) {
      if (provider is! SerializableNodeProvider) {
        return;
      }

      var encoded = DsJson.encode((provider as SerializableNodeProvider).save(),
          pretty: encodePrettyJson);

      await _nodesFile.writeAsString(encoded);
    }
  }

  /// Gets the node at the specified path.
  LocalNode getNode(String path) {
    return provider.getNode(path);
  }

  /// Adds a node with the given configuration in [m] at the given [path].
  /// In order for this method to work, the node provider must be mutable.
  /// If you did not specify a custom node provider, the created provider is mutable.
  LocalNode addNode(String path, Map m) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    return (provider as MutableNodeProvider).addNode(path, m);
  }

  /// Removes the method at the specified [path].
  /// In order for this method to work, the node provider must be mutable.
  /// If you did not specify a custom node provider, the created provider is mutable.
  void removeNode(String path) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    (provider as MutableNodeProvider).removeNode(path);
  }

  /// Updates the value of the node at the given [path] to [value].
  /// In order for this method to work, the node provider must be mutable.
  /// If you did not specify a custom node provider, the created provider is mutable.
  void updateValue(String path, dynamic value) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    (provider as MutableNodeProvider).updateValue(path, value);
  }

  /// Gets the node specified at [path].
  LocalNode operator [](String path) => provider[path];

  /// Gets the root node.
  LocalNode operator ~() => this["/"];

  /// If only [path] is specified, this method fetches the value of the node at the given path.
  /// If [value] is also specified, it will set the value of the
  /// node at the given path to the specified value, and return that value.
  dynamic val(String path, [value = unspecified]) {
    if (value is Unspecified) {
      return this[path].lastValueUpdate.value;
    } else {
      updateValue(path, value);
      return value;
    }
  }
}

/// Provides the base APIs for the DSLink SDK on the Dart VM.
library dslink.client;

import "dart:async";
import "dart:io";
import "dart:convert";

import "package:args/args.dart";

import "common.dart";
import "requester.dart";
import "responder.dart";
import "utils.dart";
import "io.dart";
import "src/crypto/pk.dart";
import "src/http/websocket_conn.dart";

import "package:logging/logging.dart";

import "package:dslink/broker_discovery.dart" show BrokerDiscoveryClient;

export "src/crypto/pk.dart";

part "src/http/client_link.dart";

/// A Handler for Argument Results
typedef void OptionResultsHandler(ArgResults results);

typedef _TwoArgumentProfileFunction(String path, SimpleNodeProvider provider);

/// Main Entry Point for DSLinks on the Dart VM
class LinkProvider {
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
  String command = "link";

  /// Are we a responder?
  bool isResponder = true;

  /// Default Nodes
  Map<String, dynamic> defaultNodes;

  /// Profiles
  Map<String, Function> profiles;

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

  /// Strict TLS connections?
  bool strictTls = false;

  /// Default Log Level.
  String defaultLogLevel = "INFO";

  /// Log Tag
  String logTag;

  /// Save Private Key?
  bool savePrivateKey = false;

  Requester overrideRequester;
  Responder overrideResponder;

  Map linkData;

  /// connect to user home space
  String home;

  /// connection token
  String token;

  /// Create a Link Provider.
  /// [args] are the command-line arguments to pass in.
  /// [prefix] is the link name.
  /// [isRequester] specifies if you are a requester or not.
  /// [isResponder] specifies if you a responder or not.
  /// [command] is the command name for this link.
  /// Both [defaultNodes] and [nodes] specify the default nodes to initialize if a nodes.json is not present.
  /// [profiles] specify the profiles for this link.
  /// [provider] is a node provider. If it is not specified, one will be created for you.
  /// [enableHttp] toggles whether to enable HTTP fallbacks.
  /// [encodePrettyJson] specifies whether to encode pretty JSON files when writing the nodes.json
  /// [autoInitialize] specifies whether to initialize the link inside the constructor.
  /// [strictOptions] toggles allowing trailing options in the argument parser.
  /// [exitOnFailure] toggles exiting when the link fails.
  /// [loadNodesJson] specifies whether to load the nodes.json file or not.
  /// [strictTls] specifies if a link to a secure broker should fail, if the TLS Certificate is bad.
  /// [defaultLogLevel] specifies the default log level.
  /// [nodeProvider] is the same as [provider]. It is provided for backwards compatibility.
  /// [commandLineOptions] specifies a map of an option name to a default value, for use in expanding the command parameters.
  LinkProvider(
      this.args,
      this.prefix,
      {
        this.isRequester: false,
        this.command: "link",
        this.isResponder: true,
        this.defaultNodes,
        Map<String, dynamic> nodes,
        this.profiles,
        this.provider,
        this.enableHttp: true,
        this.encodePrettyJson: false,
        bool autoInitialize: true,
        this.strictOptions: false,
        this.exitOnFailure: true,
        this.loadNodesJson: true,
        this.strictTls: false,
        this.defaultLogLevel: "INFO",
        this.savePrivateKey: true,
        this.overrideRequester,
        this.overrideResponder,
        NodeProvider nodeProvider, // For Backwards Compatibility
        this.linkData,
        Map<String, String> commandLineOptions
      }) {
    exitOnFailure = Zone.current["dslink.runtime.config"] is! Map;

    if (nodeProvider != null) {
      provider = nodeProvider;
    }

    if (nodes != null) {
      defaultNodes = nodes;
    }

    if (commandLineOptions != null) {
      for (String key in commandLineOptions.keys) {
        addCommandLineOption(key, commandLineOptions[key]);
      }
    }

    if (autoInitialize) {
      init();
    }
  }

  String get basePath => _basePath;

  String _basePath = Directory.current.path;
  String _watchFile;
  String _logFile;

  bool _configured = false;

  ArgParser _argp = new ArgParser();
  ArgResults _parsedArguments;
  ArgResults get parsedArguments => _parsedArguments;

  String _logLevelToName(Level level) {
    return level.name.toLowerCase();
  }

  void addCommandLineOption(String name, [String defaultValue = ""]) {
    _argp = _argp == null ? new ArgParser(allowTrailingOptions: !strictOptions) : _argp;
    _argp.addOption(name, defaultsTo: defaultValue);
  }
  
  String getCommandLineValue(String name) =>
    parsedArguments == null ? null : parsedArguments[name];

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
      argp = _argp == null ? _argp = new ArgParser(allowTrailingOptions: !strictOptions) : _argp;
    }

    argp.addOption("broker",
        abbr: "b",
        help: "Broker URL",
        defaultsTo: "http://127.0.0.1:8080/conn");
    argp.addOption("name", abbr: "n", help: "Link Name");
    argp.addOption("home", help: "Home");
    argp.addOption("token", help: "Token");
    argp.addOption("base-path", help: "Base Path for DSLink");
    argp.addOption("watch-file", help: "Watch File for DSLink", hide: true);
    argp.addOption("log-file", help: "Log File for DSLink");

    List<String> logLevelNames = Level.LEVELS.map(_logLevelToName).toList()
      ..addAll(['auto', 'error', 'debug', 'warn', 'trace']);

    argp.addOption("log",
        abbr: "l",
        allowed: logLevelNames,
        help: "Log Level",
        defaultsTo: "AUTO");
    argp.addFlag("help",
        abbr: "h", help: "Displays this Help Message", negatable: false);
    argp.addFlag("discover",
        abbr: "d", help: "Automatically Discover a Broker", negatable: false);
    argp.addFlag("strictTls",
        help: "Enforces valid SSL/TLS certificates for secure connections to " +
            "broker.");

    ArgResults opts = _parsedArguments = argp.parse(args);

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

    if (opts["watch-file"] != null) {
      _watchFile = opts["watch-file"];
    }

    _logFile = opts["log-file"];
    if (opts["strictTls"]) {
      strictTls = true;
    }

    if (_logFile != null) {
      var file = new File(_logFile);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      logger.clearListeners();
      IOSink out = _logFileOut = file.openWrite(mode: FileMode.APPEND);
      logger.onRecord.listen((record) {
        out.writeln("[${new DateTime.now()}][${record.level.name}] ${record.message}");
        if (record.error != null) {
          out.writeln(record.error);
        }

        if (record.stackTrace != null) {
          out.writeln(record.stackTrace);
        }

        out.flush();
      });
    }

    if (_watchFile != null) {
      var file = new File(_watchFile);
      StreamSubscription sub;
      sub = file.watch(events: FileSystemEvent.DELETE).listen((_) {
        close();
        sub.cancel();

        if (_logFileOut != null) {
          try {
            _logFileOut.close();
          } catch (e) {}
        }
      });
    }

    if (const bool.fromEnvironment("dslink.debugger.console", defaultValue: false)) {
      readStdinLines().listen((String cmd) {
        if (cmd == "list-stored-nodes") {
          if (provider is SimpleNodeProvider) {
            SimpleNodeProvider prov = provider;
            print(prov.nodes.keys.join("\n"));
          } else {
            print("Not a SimpleNodeProvider.");
          }
        } else if (cmd == "list-stub-nodes") {
          if (provider is SimpleNodeProvider) {
            SimpleNodeProvider prov = provider;
            for (var node in prov.nodes.values) {
              Path p = new Path(node.path);
              if (prov.nodes[p.parentPath] == null) {
                print(node.path);
              } else if (!prov.nodes[p.parentPath].children.containsKey(p.name)) {
                print(node.path);
              }
            }
          } else {
            print("Not a SimpleNodeProvider.");
          }
        }
      });
    }

    {
      var runtimeConfig = Zone.current["dslink.runtime.config"];

      if (runtimeConfig != null) {
        var closeHandler = () {
          close();

          if (_logFileOut != null) {
            try {
              _logFileOut.close();
            } catch (e) {}
          }
        };

        runtimeConfig["closeHandler"] = closeHandler;
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

    brokerUrl = opts["broker"];
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
    home = opts["home"];
    token = opts["token"];

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
      if (!brokerUrl.startsWith("http")) {
        brokerUrl = "http://$brokerUrl";
      }
    }

    File keyFile = getConfig("key") == null
        ? new File("${_basePath}/.dslink.key")
        : new File.fromUri(Uri.parse(getConfig("key")));
    String key;

    try {
      key = keyFile.readAsStringSync();
      privateKey = new PrivateKey.loadFromString(key);
    } catch (err) {}

    if (key == null || key.length != 131) {
      // 43 bytes d, 87 bytes Q, 1 space
      // generate the key
      if (DSRandom.instance.needsEntropy) {
        String macs;
        if (Platform.isWindows) {
          macs = Process.runSync("getmac", []).stdout.toString();
        } else {
          try {
            macs = Process.runSync("arp", ["-an"]).stdout.toString();
          } catch (e) {
            try {
              var envs = "";
              for (var i in Platform.environment.keys) {
                envs += "${i}=${Platform.environment[i]}\n";
              }
              macs = envs;
            } catch (e) {}
          }
        }
        // randomize the PRNG with the system mac (as well as timestamp)
        DSRandom.instance.addEntropy(macs);
      }
      privateKey = new PrivateKey.generateSync();
      key = privateKey.saveToString();
      if (savePrivateKey) {
        keyFile.writeAsStringSync(key);
      }
    }
    SimpleNode.initEncryption(privateKey.saveToString());
    
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

  /// Remote Path of Responder
  String get remotePath => link.remotePath;

  IOSink _logFileOut;
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

    if (_initialized) {
      return;
    }

    _initialized = true;

    if (profiles != null) {
      for (var key in profiles.keys.toList()) {
        var value = profiles[key];

        if (value is _TwoArgumentProfileFunction) {
          profiles[key] = (String path) {
            return value(path, provider);
          };
        }
      }
    }

    if (provider == null) {
      provider = new SimpleNodeProvider(null, profiles);
      (provider as SimpleNodeProvider).setPersistFunction(saveAsync);
    }

    loadNodesFile();

    void doRun() {
      link = createHttpLink();
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
          logger.info("Discovered Broker at ${broker}");
          brokerUrl = broker;
          doRun();
        } catch (e, stack) {
          logger.severe("Failed to discover a broker.", e, stack);
          exit(1);
        }
      });
    } else {
      doRun();
    }
  }

  HttpClientLink createHttpLink() {
    var client = new HttpClientLink(
      brokerUrl,
      prefix,
      privateKey,
      isRequester: isRequester,
      isResponder: isResponder,
      nodeProvider: provider,
      overrideRequester: overrideRequester,
      overrideResponder: overrideResponder,
      strictTls: strictTls,
      home: home,
      token: token,
      linkData: linkData
    );
    client.logName = logTag;
    return client;
  }

  void loadNodesFile() {
    if (provider is SerializableNodeProvider &&
      !_reconnecting) {
      _nodesFile = getConfig("nodes") == null
        ? new File("${_basePath}/nodes.json")
        : new File.fromUri(Uri.parse(getConfig("nodes")));
      Map<String, dynamic> loadedNodesData;

      if (loadNodesJson) {
        _nodesFile = getConfig("nodes") == null
          ? new File("${_basePath}/nodes.json")
          : new File.fromUri(Uri.parse(getConfig("nodes")));
        try {
          String nodesStr = _nodesFile.readAsStringSync();
          var json = DsJson.decode(nodesStr);

          if (json is Map<String, dynamic>) {
            loadedNodesData = json;
          }
        } catch (err) {}
      }

      if (loadedNodesData != null) {
        onNodesDeserialized(loadedNodesData);
        (provider as SerializableNodeProvider).init(loadedNodesData);
      } else if (defaultNodes != null) {
        (provider as SerializableNodeProvider).init(defaultNodes);
      }
    }
  }

  /// The dslink.json contents. This is only available after [configure] is called.
  Map dslinkJson;

  /// Gets a configuration value from the dslink.json
  Object getConfig(String key) {
    if (dslinkJson != null &&
        dslinkJson["configs"] is Map &&
        dslinkJson["configs"][key] is Map &&
        dslinkJson["configs"][key].containsKey("value")) {
      return dslinkJson["configs"][key]["value"];
    }
    return null;
  }

  /// Handles deserialization of node data.
  void onNodesDeserialized(Map json) {}

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

      _nodesFile.writeAsStringSync(
        DsJson.encode(
          (provider as SerializableNodeProvider).save(),
          pretty: encodePrettyJson)
      );
    }
  }

  /// Asynchronously saves the nodes.json file.
  Future saveAsync() async {
    if (_nodesFile != null && provider != null) {
      if (provider is! SerializableNodeProvider) {
        return;
      }

      var count = 0;
      while (_isAsyncSave) {
        await new Future.delayed(const Duration(milliseconds: 5));
        count++;

        if (count == 100) {
          break;
        }
      }

      var encoded = DsJson.encode(
        (provider as SerializableNodeProvider).save(),
        pretty: encodePrettyJson
      );

      _isAsyncSave = true;

      await _nodesFile.writeAsString(encoded);

      _isAsyncSave = false;
    }
  }

  bool _isAsyncSave = false;

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

  /// persist value setting to disk, default to true;
  bool get valuePersistenceEnabled {
    if (dslinkJson is Map && dslinkJson['configs'] is Map && dslinkJson['configs']['valuePersistenceEnabled'] is Map
        && dslinkJson['configs']['valuePersistenceEnabled']['value'] == false) {
      return false;
    }
    return true;
  }
  /// persist qos2 and qos3 subscription to disk, default to false;
  bool get qosPersistenceEnabled {
    if (dslinkJson is Map && dslinkJson['configs'] is Map && dslinkJson['configs']['qosPersistenceEnabled'] is Map
        && dslinkJson['configs']['qosPersistenceEnabled']['value'] == true) {
      return true;
    }
    return false;
  }
}

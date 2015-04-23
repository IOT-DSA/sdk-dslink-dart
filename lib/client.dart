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

export 'src/crypto/pk.dart';

part 'src/http/client_link.dart';
part 'src/http/client_http_conn.dart';

class LinkProvider {
  HttpClientLink link;
  SimpleNodeProvider provider;
  String brokerUrl;
  File _nodesFile;

  LinkProvider(
    List<String> args,
    String prefix,
    {
      bool isRequester: false,
      String command: 'link',
      bool isResponder: true,
      Map defaultNodes,
      Map profiles,
      NodeProvider nodeProvider,
      bool enableHttp:false
    }) {
    ArgParser argp = new ArgParser();
    argp.addOption('broker', abbr: 'b');
    argp.addOption('name', abbr: 'n');
    argp.addOption('log', defaultsTo: 'notice');
    //argp.addOption('key', abbr: 'k', defaultsTo: '.dslink.key');
    //argp.addOption('nodes', abbr: 'n', defaultsTo: 'dslink.json');
    argp.addFlag('help');

    if (args.length == 0) {
      // for debugging
      args = ['-b', 'localhost:8080/conn', '--log', 'debug'];
    }

    ArgResults opts = argp.parse(args);

    String log = opts['log'];
    updateLogLevel(log);

    String helpStr = 'usage: $command --broker url [--config file]';

    if (opts['help'] == true) {
      print(helpStr);
      return;
    }

    brokerUrl = opts['broker'];
    if (brokerUrl == null) {
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
    Map dslinkJson;

    Object getConfig(String key) {
      if (dslinkJson != null &&
        dslinkJson['configs'] is Map &&
        dslinkJson['configs'][key] is Map &&
        dslinkJson['configs'][key].containsKey('value')) {
        return dslinkJson['configs'][key]['value'];
      }
      return null;
    }

    if (dslinkFile.existsSync()) {
      try {
        String configStr = dslinkFile.readAsStringSync();
        dslinkJson = DsJson.decode(configStr);
      } catch (err) {
      }

      if (dslinkJson == null) {
        printError('Invalid dslink.json');
        return;
      }
    } else {
      dslinkJson = {};
    }

    if (!brokerUrl.startsWith('http')) {
      brokerUrl = 'http://$brokerUrl';
    }

    File keyFile = getConfig('key') == null ? new File(".dslink.key") : new File.fromUri(Uri.parse(getConfig('key')));
    String key;
    PrivateKey prikey;

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
        macs = Process.runSync('ifconfig', []).stdout.toString();
      }
      // randomize the PRNG with the system mac (as well as timestamp)
      DSRandom.instance.randomize(macs);
      prikey = new PrivateKey.generate();
      key = prikey.saveToString();
      keyFile.writeAsStringSync(key);
    }

    if (nodeProvider == null) {
      provider = new SimpleNodeProvider(null, profiles);
      nodeProvider = provider;
      _nodesFile = getConfig('nodes') == null ? new File("dslink.json") : new File.fromUri(Uri.parse(getConfig('nodes')));
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

    link = new HttpClientLink(brokerUrl, prefix, prikey, isRequester: isRequester, isResponder: isResponder, nodeProvider: nodeProvider, enableHttp:enableHttp);
  }

  void connect() {
    if (link != null) link.connect();
  }

  void save() {
    if (_nodesFile != null && provider != null) {
      _nodesFile.writeAsStringSync(DsJson.encode(provider.save()));
    }
  }
}

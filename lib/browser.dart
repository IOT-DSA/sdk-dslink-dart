/// Main DSLink API for Browsers
library dslink.browser;

import "dart:async";

import "package:dslink/requester.dart";
import "package:dslink/responder.dart";
import "package:dslink/browser_client.dart";

import "package:dslink/src/crypto/pk.dart";
import "package:dslink/utils.dart";

export "package:dslink/common.dart";
export "package:dslink/requester.dart";
export "package:dslink/responder.dart";
export "package:dslink/browser_client.dart";
export "package:dslink/utils.dart" show Scheduler, Interval, DSLinkJSON, updateLogLevel;
export "package:dslink/src/crypto/pk.dart" show PrivateKey;

/// DSLink Provider for the Browser
class LinkProvider {
  BrowserECDHLink link;
  Map defaultNodes;
  Map profiles;
  bool loadNodes;
  NodeProvider provider;
  DataStorage dataStore;
  PrivateKey privateKey;
  String brokerUrl;
  String prefix;
  bool isRequester;
  bool isResponder;

  LinkProvider(this.brokerUrl, this.prefix, {
    this.defaultNodes,
    this.profiles,
    this.provider,
    this.dataStore,
    this.loadNodes: false,
    this.isRequester: true,
    this.isResponder: true
  }) {
    if (dataStore == null) {
      dataStore = LocalDataStorage.INSTANCE;
    }
  }

  bool _initCalled = false;

  Future init() async {
    _initCalled = true;

    privateKey = await getPrivateKey(storage: dataStore);

    if (provider == null) {
      provider = new SimpleNodeProvider(null, profiles);
    }

    if (loadNodes && provider is SerializableNodeProvider) {
      if (!(await dataStore.has("dsa_nodes"))) {
        (provider as SerializableNodeProvider).init(defaultNodes);
      } else {
        (provider as SerializableNodeProvider).init(DsJson.decode(await dataStore.get("dsa_nodes")));
      }
    } else {
      (provider as SerializableNodeProvider).init(defaultNodes);
    }

    link = new BrowserECDHLink(
        brokerUrl,
        prefix,
        privateKey,
        nodeProvider: provider,
        isRequester: isRequester,
        isResponder: isResponder
    );
  }

  Future resetSavedNodes() async {
    await dataStore.remove("dsa_nodes");
  }

  Future save() async {
    if (provider is! SerializableNodeProvider) {
      return;
    }

    await dataStore.store("dsa_nodes", DsJson.encode((provider as SerializableNodeProvider).save()));
  }

  void connect() {
    if (!_initCalled) {
      init().then((_) => link.connect());
    } else {
      link.connect();
    }
  }

  void close() {
    if (link != null) {
      link.close();
      link = null;
    }
  }

  LocalNode getNode(String path) {
    return provider.getNode(path);
  }

  LocalNode addNode(String path, Map m) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    return (provider as MutableNodeProvider).addNode(path, m);
  }

  void removeNode(String path) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    (provider as MutableNodeProvider).removeNode(path);
  }

  void updateValue(String path, dynamic value) {
    if (provider is! MutableNodeProvider) {
      throw new Exception("Unable to Modify Node Provider: It is not mutable.");
    }
    (provider as MutableNodeProvider).updateValue(path, value);
  }

  LocalNode operator [](String path) => provider[path];

  Requester get requester => link.requester;

  Future<Requester> get onRequesterReady => link.onRequesterReady;
}

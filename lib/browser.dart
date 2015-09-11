/// Main DSLink API for Browsers
library dslink.browser;

import "dart:async";
import "dart:html";

import "dart:typed_data";

import "package:dslink/requester.dart";
import "package:dslink/responder.dart";
import "package:dslink/browser_client.dart";
import "package:dslink/common.dart";

import "package:dslink/src/crypto/pk.dart";
import "package:dslink/utils.dart";

import "package:crypto/crypto.dart";

export "package:dslink/common.dart";
export "package:dslink/requester.dart";
export "package:dslink/responder.dart";
export "package:dslink/browser_client.dart";
export "package:dslink/utils.dart"
    show
        Scheduler,
        Interval,
        DSLinkJSON,
        updateLogLevel,
        buildEnumType,
        buildActionIO,
        ByteDataUtil;
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

  LinkProvider(this.brokerUrl, this.prefix,
      {this.defaultNodes,
      this.profiles,
      this.provider,
      this.dataStore,
      this.loadNodes: false,
      this.isRequester: true,
      this.isResponder: true}) {
    if (dataStore == null) {
      dataStore = LocalDataStorage.INSTANCE;
    }
  }

  bool _initCalled = false;

  Future init() {
    _initCalled = true;

    if (provider == null) {
      provider = new SimpleNodeProvider(null, profiles);
    }
    // move the waiting part of init into a later frame 
    // we need to make sure provider is created at the first frame
    // not affected by any async code
    return initAsync();
  }

  Future initAsync() async {
    privateKey = await getPrivateKey(storage: dataStore);

    if (loadNodes && provider is SerializableNodeProvider) {
      if (!(await dataStore.has("dsa_nodes"))) {
        (provider as SerializableNodeProvider).init(defaultNodes);
      } else {
        (provider as SerializableNodeProvider)
            .init(DsJson.decode(await dataStore.get("dsa_nodes")));
      }
    } else {
      (provider as SerializableNodeProvider).init(defaultNodes);
    }
  }

  Future resetSavedNodes() async {
    await dataStore.remove("dsa_nodes");
  }

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

  Future save() async {
    if (provider is! SerializableNodeProvider) {
      return;
    }

    await dataStore.store("dsa_nodes",
        DsJson.encode((provider as SerializableNodeProvider).save()));
  }

  void syncValue(String path) {
    var n = this[path];
    n.updateValue(n.lastValueUpdate.value, force: true);
  }

  Future connect() {
    Future run() {
      link = new BrowserECDHLink(brokerUrl, prefix, privateKey,
          nodeProvider: provider,
          isRequester: isRequester,
          isResponder: isResponder);

      link.connect();
      return link.onConnected;
    }

    if (link != null) {
      throw new StateError("Link is already connected!");
    }

    if (!_initCalled) {
      return init().then((_) => run());
    } else {
      return run();
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

  dynamic val(String path, [value = unspecified]) {
    if (value is Unspecified) {
      return this[path].lastValueUpdate.value;
    } else {
      updateValue(path, value);
      return value;
    }
  }

  LocalNode operator [](String path) => provider[path];

  Requester get requester => link.requester;

  Future<Requester> get onRequesterReady => link.onRequesterReady;

  LocalNode operator ~() => this["/"];
}

class BrowserUtils {
  static Future<String> fetchBrokerUrlFromPath(
      String path, String otherwise) async {
    try {
      return (await HttpRequest.getString(path)).trim();
    } catch (e) {
      return otherwise;
    }
  }

  static String createBinaryUrl(ByteData input,
      {String type: "application/octet-stream"}) {
    Uint8List data = ByteDataUtil.toUint8List(input);
    return "data:${type};base64,${CryptoUtils.bytesToBase64(data)}";
  }
}

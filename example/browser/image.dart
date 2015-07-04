import "package:dslink/browser.dart";

import "dart:html";
import "dart:typed_data";
import "dart:convert";

import "package:crypto/crypto.dart";

LinkProvider link;
Requester requester;
ImageElement image;

main() async {
  image = querySelector("#image");

  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://localhost:8080/conn");

  link = new LinkProvider(brokerUrl, "ImageDisplay-", isRequester: true);

  await link.connect();
  requester = await link.onRequesterReady;
  window.onHashChange.listen((HashChangeEvent event) {
    setup(window.location.hash.substring(1));
  });

  setup(window.location.hash.isNotEmpty ? window.location.hash.substring(1) : "/conns/Storage/images/image");
}

setup(String path) {
  print("Displaying Image from ${path}");

  if (listener != null) {
    listener.cancel();
    listener = null;
  }

  listener = requester.subscribe(path, handleValueUpdate);
}

handleValueUpdate(ValueUpdate update) {
  if (update.value == null) {
    return;
  }

  image.src = BrowserUtils.createBinaryUrl(update.value);
}

ReqSubscribeListener listener;

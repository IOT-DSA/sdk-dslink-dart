import "package:dslink/browser.dart";

import "dart:html";
import "dart:typed_data";
import "dart:js";

LinkProvider link;
Requester requester;
VideoElement video;
JsObject videoObject;

main() async {
  //updateLogLevel("ALL");
  video = querySelector("#video");
  videoObject = new JsObject.fromBrowserObject(video);

  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://localhost:8080/conn");

  link = new LinkProvider(brokerUrl, "VideoDisplay-", isRequester: true);

  await link.connect();
  requester = await link.onRequesterReady;
  window.onHashChange.listen((HashChangeEvent event) {
    setup(window.location.hash.substring(1));
  });

  await setup(window.location.hash.isNotEmpty ? window.location.hash.substring(1) : "/downstream/File/video");
}

setup(String path) async {
  print("Displaying Video from ${path}");

  var sizePath = path + "/size";
  var getChunkPath = path + "/readBinaryChunk";

  int size = (await requester.getNodeValue(sizePath)).value;

  var source = new MediaSource();
  video.src = Url.createObjectUrlFromSource(source);

  source.addEventListener("sourceopen", (e) async {
    var buff = source.addSourceBuffer('video/webm; codecs="vorbis,vp8"');

    var chunkSize = (size / CHUNK_COUNT).ceil();

    for (var i = 0; i < CHUNK_COUNT; ++i) {
      var start = chunkSize * i;
      var end = start + chunkSize;
      RequesterInvokeUpdate update = await requester.invoke(getChunkPath, {
        "start": start,
        "end": start + chunkSize
      }).first;

      Map map = update.updates[0];
      ByteData data = map["data"];

      print("Chunk #${i}");

      buff.appendBuffer(data.buffer);
    }

    buff.abort();
    source.endOfStream();
  });

  video.autoplay = true;
  video.play();
}

int CHUNK_COUNT = 200;

import "package:dslink/browser.dart";

import "dart:html";
import "dart:typed_data";
import "dart:js";

LinkProvider link;
Requester requester;
VideoElement video;
JsObject videoObject;

String codec = 'video/webm; codecs="vorbis, vp8"';

main() async {
  //updateLogLevel("ALL");
  video = querySelector("#video");
  videoObject = new JsObject.fromBrowserObject(video);

  var brokerUrl = await BrowserUtils.fetchBrokerUrlFromPath("broker_url", "http://localhost:8080/conn");

  link = new LinkProvider(brokerUrl, "VideoDisplay-", isRequester: true, isResponder: false);

  await link.connect();
  requester = await link.onRequesterReady;

  String getHash() {
    if (window.location.hash.isEmpty) {
      return "";
    }
    var h = window.location.hash.substring(1);
    if (h.startsWith("mpeg4:")) {
      codec = 'video/mp4; codecs="avc1.42E01E, mp4a.40.2"';
      h = h.substring("mpeg4:".length);
    }
    return h;
  }

  window.onHashChange.listen((event) {
    setup(getHash());
  });

  await setup(getHash().isNotEmpty ? getHash() : "/downstream/File/video");
}

setup(String path) async {
  print("Displaying Video from ${path}");

  var sizePath = path + "/size";
  var getChunkPath = path + "/readBinaryChunk";

  int size = (await requester.getNodeValue(sizePath)).value;

  print("Video Size: ${size} bytes");

  var source = new MediaSource();

  source.addEventListener("sourceopen", (e) async {
    CHUNK_COUNT = (size / 512000).round();
    var chunkSize = (size / CHUNK_COUNT).ceil();

    print("Chunk Size: ${chunkSize} bytes");

    var buff = source.addSourceBuffer(codec);
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

      print("${start}-${end}");

      if (i + 1 == CHUNK_COUNT) {
        source.endOfStream();
      } else {
        buff.appendBuffer(data.buffer);
      }

      await buff.on["updateend"].first;
    }

    source.endOfStream();
  });

  video.src = Url.createObjectUrlFromSource(source);
  video.autoplay = true;
  video.play();
}

int CHUNK_COUNT = 200;

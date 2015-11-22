import "package:dslink/dslink.dart";

import "dart:io";
import "dart:typed_data";

LinkProvider link;

main(List<String> args) async {
  var file = new File.fromUri(Platform.script.resolve("message.png"));

  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "Simple-", defaultNodes: {
    "Message": {
      r"$type": "string", // The type of the node is a string.
      r"$writable": "write", // This node's value can be set by a requester.
      "?value": "Hello World", // The default message value.
      "@icon": "dart-sdk-simple/message"
    }
  }, encodePrettyJson: true);

  // Connect to the broker.
  link.connect();

  (link.provider as SimpleNodeProvider).iconResolver = (String name) async {
    if (name == "dart-sdk-simple/message") {
      Uint8List list = await file.readAsBytes();
      return list.buffer.asByteData();
    } else {
      return null;
    }
  };

  // Save the message when it changes.
  link.onValueChange("/Message").listen((_) => link.save());
}

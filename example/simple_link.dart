import "package:dslink/dslink.dart";
import "dart:io";
import "dart:typed_data";

LinkProvider link;

main(List<String> args) async {
  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "Simple-", defaultNodes: {
    "message": {
      r"$name": "Message", // The pretty name of this node.
      r"$type": "string", // The type of the node is a string.
      r"$writable": "write", // This node's value can be set by a requester.
      "?value": null, // The default message value.
      "@icon": "dart-example-simple/message"
    }
  }, encodePrettyJson: true, commandLineOptions: {
    "default-message": "Hello World"
  });

  SimpleNodeProvider provider = link.provider;

  if (provider["/message"].value == null) {
    provider.updateValue("/message", link.parsedArguments["default-message"]);
  }

  provider.setIconResolver((String name) async {
    if (name == "dart-example-simple/message") {
      var file = new File(Platform.script.resolve("message.png").toFilePath());
      if (await file.exists()) {
        Uint8List data = await file.readAsBytes();
        return data.buffer.asByteData(
          data.offsetInBytes,
          data.lengthInBytes
        );
      }
    }
    return null;
  });

  // Connect to the broker.
  link.connect();

  // Save the message when it changes.
  if (link.persistValue) {
    link.onValueChange("/message").listen((_) => link.save());
  }
}

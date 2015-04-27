# DSLink SDK for Dart

With the DSLink SDK, you can provide IoT data to any DSA compatible consumer.

## Getting Started

### Starting a Broker

```bash
dart bin/broker.dart
```

You can edit the server configuration using `broker.json`

### Example Link

For more examples, see [this page](https://github.com/IOT-DSA/sdk-dslink-dart/tree/master/example).

```dart
import "package:dslink/client.dart";
import "package:dslink/responder.dart";

LinkProvider link;

main(List<String> args) async {
  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "Simple-", defaultNodes: {
    "Message": {
      r"$type": "string", // The type of the node is a string.
      r"$writable": "write", // This node's value can be set by a responder link.
      "?value": "Hello World" // The default message value.
    }
  });

  // Connect to the broker.
  link.connect();

  // Save the message when it changes.
  link.provider.getNode("/Message").subscribe((update) => link.save());
}
```

## Links

- [DSA Site](http://iot-dsa.org/)
- [Community Wiki](https://github.com/IOT-DSA/community/wiki)

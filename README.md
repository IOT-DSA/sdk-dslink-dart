# DSLink SDK for Dart

With the DSLink SDK, you can provide IoT data to any DSA compatible consumer.

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/downloads)
- [Dart SDK](https://www.dartlang.org/downloads/)

### Install

```bash
pub global activate -sgit https://github.com/IOT-DSA/sdk-dslink-dart.git
```

### Start a Broker

```bash
dsbroker # If you have the pub global executable path setup.
pub global run dslink:broker # If you do not have the pub global executable path setup.
```

You can edit the server configuration using `broker.json`

### Create a Link

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

### Start a Link

```bash
dart path/to/link.dart # Start a link that connects to a broker at http://127.0.0.1:8080/conn
dart path/to/link.dart --broker http://my.broker:8080/conn # Start a link that connects to the specified broker.
```

## Links

- [DSA Site](http://iot-dsa.org/)
- [Community Wiki](https://github.com/IOT-DSA/community/wiki)

# DSLink SDK for Dart

DSLink SDK for Dart

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/downloads)
- [Dart SDK](https://www.dartlang.org/downloads/)

### Install

```bash
pub global activate -sgit https://github.com/IOT-DSA/sdk-dslink-dart.git # Globally install the DSA Dart SDK
```

### Start a Broker

```bash
dsbroker # If you have the pub global executable path setup.
pub global run dslink:broker # If you do not have the pub global executable path setup.
```

To connect a broker to another broker:

```bash
dsbroker --broker http://my.broker.org:8080/conn # Connect a broker to another broker
```

You can edit the server configuration using `broker.json`. For more information about broker configuration, see [this page](https://github.com/IOT-DSA/sdk-dslink-dart/wiki/Configuring-a-Broker).

### Create a Link

For more examples, see [this page](https://github.com/IOT-DSA/sdk-dslink-dart/tree/master/example).

```dart
import "package:dslink/dslink.dart";

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
  link["/Message"].subscribe((update) => link.save());
}
```

### Start a Link

```bash
dart path/to/link.dart # Start a link that connects to a broker at http://127.0.0.1:8080/conn
dart path/to/link.dart --broker http://my.broker:8080/conn # Start a link that connects to the specified broker.
```

## Links

- [DSA Site](http://iot-dsa.org/)
- [DSA Wiki](https://github.com/IOT-DSA/docs/wiki)

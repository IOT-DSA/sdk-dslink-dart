# DSLink SDK for Dart

With the DSLink SDK, you can provide IoT data to any DSA compatible consumer.

## Getting Started

### Starting a Broker

```bash
dart bin/broker.dart
```

You can edit the server configuration using `broker.json`

### Example Link

```dart
import 'package:dslink/client.dart';
import 'package:dslink/utils.dart';
import 'package:dslink/responder.dart';

LinkProvider link;

main(List<String> args) async {
  link = new LinkProvider(args, "Example-", defaultNodes: {
    "Message": {
      r"$type": "string",
      "?value": "Hello World"
    }
  });

  link.connect();
}
```

## Links

- [DSA Site](http://iot-dsa.org/)
- [Community Wiki](https://github.com/IOT-DSA/community/wiki)

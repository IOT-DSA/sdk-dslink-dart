# DSLink SDK for Dart

With the DSLink SDK, you can provide IoT data to any DSA compatible consumer.

## Getting Started

DSLink's API is very simple!

```dart
import "package:dslink/link.dart";

void main() {
  var link = new DSLink("MyLink");
  var examples = link.createRootNode("Examples");
  var integerNode = examples.createChild("Integer Point 1", value: 1);
  
  link.connect("broker.example.com").then((_) {
    print("Connected.");
  });
}

```

## Links

- [DSA Site](http://iot-dsa.org/)
- [Community Wiki](https://github.com/IOT-DSA/community/wiki)

# DSLink SDK for Dart

A DSLink SDK for Dart

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
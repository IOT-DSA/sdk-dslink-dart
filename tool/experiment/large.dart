import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";

LinkProvider link;

int current = 0;

main(List<String> args) {
  link = new LinkProvider(args, "Large-", defaultNodes: {
    "Generate": {
      r"$invokable": "write",
      r"$is": "generate",
      r"$params": [
        {
          "name": "count",
          "type": "number",
          "default": 50
        }
      ]
    }
  }, profiles: {
    "generate": (String path) => new SimpleActionNode(path, (Map<String, dynamic> params) {
      var count = params["count"] != null ? params["count"] : 50;
      for (var i = 1; i <= count; i++) {
        link.addNode("/Node_${i}", {
          r"$name": "Node ${i}",
          "String_Value": {
            r"$name": "String Value",
            r"$type": "string",
            r"$writable": "write",
            "?value": "Hello World"
          },
          "Number_Value": {
            r"$name": "Number Value",
            r"$type": "number",
            r"$writable": "write",
            "?value": 5.0
          },
          "Integer_Value": {
            r"$name": "Integer Value",
            r"$type": "number",
            r"$writable": "write",
            "?value": 5
          }
        });
        current++;
      }
    })
  });

  link.connect();
}

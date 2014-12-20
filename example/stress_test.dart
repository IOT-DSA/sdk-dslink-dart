import "package:dslink/link.dart";

const ValueType LETTER = const ValueType("enum", enumValues: const [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z"
]);

void main(args) {
  var link = new DSLink("Dart Link Stress Test", host: "rnd.iot-dsa.org", debug: args.contains("-d") || args.contains("--debug"));

  for (var i = 1; i <= 50000; i++) {
    var node = link.createRootNode("Node ${i}");
    var integerNode = node.createChild("Integer Point 1", value: 1);
    var stringNode = node.createChild("String Point 1", value: "Hello World");
    var doubleNode = node.createChild("Double Point 1", value: 2.352);
    var boolNode = node.createChild("Boolean Point 1", value: true);
    var letterNode = node.createChild("Letter Point 1", value: new Value(new DateTime.now(), LETTER, "A"));

    boolNode.createAction("SetValue", params: {
        "value": ValueType.BOOLEAN
    }, execute: (args) {
      boolNode.value = args["value"];
    });

    letterNode.createAction("SetValue", params: {
        "value": LETTER
    }, execute: (args) {
      letterNode.value = args["value"];
    });

    node.createAction("GetTable", hasTableReturn: true, execute: (args) {
      return new SingleRowTable({
          "Greeting": ValueType.STRING
      }, {
          "Greeting": Value.of("Hello World")
      });
    });
  }

  link.connect().then((_) {
    print("Connected.");
  });
}

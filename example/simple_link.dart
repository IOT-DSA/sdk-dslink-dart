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
  var link = new DSLink("DartLink", debug: args.contains("-d") || args.contains("--debug"));
  var types = link.createRootNode("Types");
  var integerNode = types.createChild("Integer Point 1", value: 1);
  var stringNode = types.createChild("String Point 1", value: "Hello World");
  var doubleNode = types.createChild("Double Point 1", value: 2.352);
  var boolNode = types.createChild("Boolean Point 1", value: true);
  var letterNode = types.createChild("Letter Point 1", value: new Value(new DateTime.now(), LETTER, "A"));
  
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
  
  types.createAction("GetTable", hasTableReturn: true, execute: (args) {
    return new SingleRowTable({
      "Greeting": ValueType.STRING
    }, {
      "Greeting": Value.of("Hello World")
    });
  });
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
  });
}

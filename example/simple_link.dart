import "package:dslink/link.dart";

void main() {
  var link = new DSLink("DartLink");
  var types = link.createRootNode("Types");
  var integerNode = types.createChild("Integer", value: 1);
  var stringNode = types.createChild("String", value: "Hello World");
  var doubleNode = types.createChild("Double", value: 2.352);
  var boolNode = types.createChild("Boolean", value: true);
  boolNode.addAction(new DSAction("SetValue", params: {
    "value": ValueType.BOOLEAN
  }, execute: (args) {
    boolNode.value = args["value"];
  }));
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
  });
}
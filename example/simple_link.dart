import "package:dslink/link.dart";

const String HASH_ICON = "https://www.hscripts.com/freeimages/icons/web-basic-icons/hash/hash19.gif";

void main() {
  var link = new DSLink("DartLink");
  var types = link.createRootNode("Types");
  var integerNode = types.createChild("Integer", value: 1, icon: HASH_ICON);
  var stringNode = types.createChild("String", value: "Hello World");
  var doubleNode = types.createChild("Double", value: 2.352);
  var boolNode = types.createChild("Boolean", value: true);
  
  boolNode.createAction("SetValue", params: {
    "value": ValueType.BOOLEAN
  }, execute: (args) {
    boolNode.value = args["value"];
  });
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
  });
}
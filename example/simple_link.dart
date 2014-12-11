import "package:dslink/dslink.dart";

void main() {
  var link = new DSLink("DartLink");
  var types = link.createRootNode("Types");
  var integerNode = types.createChild("Integer", value: 1);
  var stringNode = types.createChild("String", value: "Hello World");
  var doubleNode = types.createChild("Double", value: 2.352);
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
  });
}
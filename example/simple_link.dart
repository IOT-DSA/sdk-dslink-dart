import "package:dslink/dslink.dart";
import "dart:async";

void main() {
  var link = new DSLink("DartLink");
  var testA = new DSNode("TestA");
  var testB = new DSNode("TestB");
  testA.addChild(testB);
  testB.value = Value.of(1);
  link.rootNode.addChild(testA);
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
    
    var timer = new Timer.periodic(new Duration(seconds: 5), (t) {
      testB.value = Value.of(testB.value.toInteger() + 1);
    });
  });
}
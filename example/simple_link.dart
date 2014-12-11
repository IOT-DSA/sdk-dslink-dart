import "package:dslink/dslink.dart";
import "dart:async";

void main() {
  var link = new DSLink("DartLink");
  var testA = link.createRootNode("TestA");
  var testB = testA.createChild("TestB");

  testB.value = Value.of(1);
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
    
    var timer = new Timer.periodic(new Duration(seconds: 5), (t) {
      testB.value = Value.of(testB.value.toInteger() + 1);
    });
  });
}
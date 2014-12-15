import "dart:async";

import "package:dslink/link.dart";

void main() {
  var link = new DSLink("DartLinkRecording", debug: true);
  var advanced = link.createRootNode("Advanced Nodes");
  var counter = advanced.createChild("Counter", recording: true, value: 1);
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
    
    new Timer.periodic(new Duration(seconds: 1), (timer) {
      counter.value = counter.value.toInteger() + 1;
    });
  });
}

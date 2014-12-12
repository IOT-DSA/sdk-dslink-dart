import "package:dslink/link.dart";

import "package:linux/leds.dart";

void main() {
  var link = new DSLink("Linux");
  var ledsNode = link.createRootNode("LEDs");
  var leds = LED.list();
  
  for (var led in leds) {
    var node = ledsNode.createChild(led.deviceName);
    var brightnessNode = node.createChild("Brightness", value: led.brightness);
    node.createAction("SetBrightness", params: {
      "brightness": ValueType.INTEGER
    }, execute: (args) {
      led.brightness = args["brightness"].toInteger();
    });
    
    poller(() {
      brightnessNode.value = led.brightness;
    }).pollEverySecond();
    
    node.createChild("Max Brightness", value: led.maxBrightness);
  }
  
  link.connect("rnd.iot-dsa.org").then((_) {
    print("Connected.");
  });
}
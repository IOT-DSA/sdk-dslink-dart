import "package:dslink/link.dart";
import "package:dslink/protocol.dart";

void main() {
  var node = new BaseNode("TestA");
  node.subscribe(new RemoteSubscriber((response) {
    print(response);
  }, "Test"));
  var testB = node.createChild("TestB", value: true);
}

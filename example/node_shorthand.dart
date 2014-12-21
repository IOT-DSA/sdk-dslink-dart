import "package:dslink/link.dart";

void main() {
  var link = new DSLink("Test");
  var someOther = link.createRootNode("Hello");
  var node = link["/Hello/World/My/Name/Is/Alex Dawg"];
  print(node.path);
}
import "package:dslink/link.dart";

void main() {
  var link = new DSLink("Node Resolver");
  var testA = new DSNode("TestA");
  var testB = new DSNode("TestB");
  testA.addChild(testB);
  link.rootNode.addChild(testA);
  var node = link.resolvePath("/TestA/TestB");
  print(node.path);
}
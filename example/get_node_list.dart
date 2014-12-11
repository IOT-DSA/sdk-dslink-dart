import "dart:convert";
import "package:dslink/dslink.dart";

void main() {
  var link = new DSLink("Node Resolver");
  var testA = new DSNode("TestA");
  var testB = new DSNode("TestB");
  var testC = new DSNode("TestC");
  testA.addChild(testB);
  testA.addChild(testC);
  link.rootNode.addChild(testA);
  (new GetNodeListMethod()..link = link).handle({
    "method": "GetNodeList",
    "path": "/TestA",
    "reqId": 1
  }, (response) {
    print(JSON.encode(response));
  });
}
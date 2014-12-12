import "dart:convert";

import "package:dslink/protocol.dart";
import "package:dslink/link.dart";

void main() {
  var link = new DSLink("Node Resolver");
  var testA = new BaseNode("TestA");
  var testB = new BaseNode("TestB");
  var testC = new BaseNode("TestC");
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
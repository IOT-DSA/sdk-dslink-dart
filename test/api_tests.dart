import "package:scheduled_test/scheduled_test.dart";
import "package:dslink/api.dart";

void main() {
  group("DSNode", () {
    test("keeps identity and changes path", () {
      var node = new BaseNode("TestA");
      expect(node.name, equals("TestA"));
      expect(node.path, equals("/"));
      var rootNode = new BaseNode("Root");
      expect(rootNode.name, equals("Root"));
      expect(rootNode.path, equals("/"));
      rootNode.addChild(node);
      expect(node.name, equals("TestA"));
      expect(node.path, equals("/TestA"));
    });
  });
}
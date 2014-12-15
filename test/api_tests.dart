import "common.dart";

void main(args) {
  setupTests(args);
  
  group("DSNode", () {
    test("should keep identity but change it's path", () {
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
  
  group("String Values", () {
    Value value;
    
    setUp(() {
      value = Value.of("Hello World");
    });
    
    test("have string type", () {
      expect(value.type, equals(ValueType.STRING));
    });
    
    test("yield a correct string value", () {
      expect(value.toString(), equals("Hello World"));
    });
    
    test("yield a correct string primitive value", () {
      expect(value.toPrimitive(), equals("Hello World"));
    });
    
    test("throw when converting to integer", () {
      expect(() => value.toInteger(), throws);
    });
    
    test("throw when converting to double", () {
      expect(() => value.toDouble(), throws);
    });
    
    test("throw when converting to boolean", () {
      expect(() => value.toBoolean(), throws);
    });
    
    test("are not usually truthy", () {
      expect(value.isTruthy(), equals(false));
    });
    
    test("are truthy when equal to true", () {
      value = Value.of("true");
      expect(value.isTruthy(), equals(true));
      value = Value.of("TRUE");
      expect(value.isTruthy(), equals(true));
      value = Value.of("false");
      expect(value.isTruthy(), equals(false));
    });
  });
}

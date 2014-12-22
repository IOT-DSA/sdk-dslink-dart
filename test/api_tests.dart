import "common.dart";

void main(args) {
  setupTests(args);

  group("BaseNode", () {
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
    
    test("wraps values correctly", () {
      var node = new BaseNode("TestA");
      
      node.value = 1;
      
      expect(node.value, isNotNull);
      expect(node.value, new isInstanceOf<Value>());
      expect(node.value.type, equals(ValueType.INTEGER));
      expect(node.value.toPrimitive(), equals(1));
      expect(node.value.toNumber(), equals(1));
      expect(node.value.toInteger(), equals(1));
    });
    
    test("creates children correctly", () {
      var root = new BaseNode("Root");
      var helloWorldNode = root.createChild("Hello World");
      expect(helloWorldNode.name, equals("Hello_World"));
      expect(helloWorldNode.path, equals("/Hello_World"));
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

  group("Integer Values", () {
    Value value;

    setUp(() {
      value = Value.of(1);
    });

    test("have integer type", () {
      expect(value.type, equals(ValueType.INTEGER));
    });

    test("yield a correct integer value", () {
      expect(value.toInteger(), equals(1));
    });

    test("yield a correct string value", () {
      expect(value.toString(), equals("1"));
    });

    test("yield a correct integer primitive value", () {
      expect(value.toPrimitive(), equals(1));
    });

    test("throw when converting to double", () {
      expect(() => value.toDouble(), throws);
    });

    test("throw when converting to boolean", () {
      expect(() => value.toBoolean(), throws);
    });

    test("are usually truthy", () {
      expect(value.isTruthy(), equals(true));
    });

    test("are not truthy when zero", () {
      value = Value.of(0);
      expect(value.isTruthy(), equals(false));
    });
  });

  group("Double Values", () {
    Value value;

    setUp(() {
      value = Value.of(1.5);
    });

    test("have double type", () {
      expect(value.type, equals(ValueType.DOUBLE));
    });

    test("yield a correct double value", () {
      expect(value.toDouble(), equals(1.5));
    });

    test("yield a correct string value", () {
      expect(value.toString(), equals("1.5"));
    });

    test("yield a correct double primitive value", () {
      expect(value.toPrimitive(), equals(1.5));
    });

    test("throw when converting to integer", () {
      expect(() => value.toInteger(), throws);
    });

    test("throw when converting to boolean", () {
      expect(() => value.toBoolean(), throws);
    });

    test("are usually truthy", () {
      expect(value.isTruthy(), equals(true));
    });

    test("are not truthy when zero", () {
      value = Value.of(0.0);
      expect(value.isTruthy(), equals(false));
    });
  });
  
  group("Boolean Values", () {
    Value value;

    setUp(() {
      value = Value.of(true);
    });

    test("have boolean type", () {
      expect(value.type, equals(ValueType.BOOLEAN));
    });

    test("yield a correct boolean value", () {
      expect(value.toBoolean(), equals(true));
    });

    test("yield a correct string value", () {
      expect(value.toString(), equals("true"));
    });

    test("yield a correct boolean primitive value", () {
      expect(value.toPrimitive(), equals(true));
    });

    test("throw when converting to integer", () {
      expect(() => value.toInteger(), throws);
    });
    
    test("throw when converting to double", () {
      expect(() => value.toDouble(), throws);
    });

    test("are truthy when true", () {
      expect(value.isTruthy(), equals(true));
    });

    test("are not truthy when false", () {
      value = Value.of(false);
      expect(value.isTruthy(), equals(false));
    });
  });

  group("Single Row Tables", () {
    Table table;

    setUp(() {
      table = new SingleRowTable({
        "name": ValueType.STRING,
        "age": ValueType.NUMBER
      }, {
        "name": Value.of("Alex"),
        "age": Value.of(15)
      });
    });

    test("have correct column count", () {
      expect(table.columnCount, equals(2));
    });

    test("only iterate once", () {
      expect(table.next(), equals(true));
      expect(table.next(), equals(false));
    });

    test("correctly selects columns", () {
      expect(table.getString(0), equals("Alex"));
      expect(table.getInteger(1), equals(15));
    });

    test("have correct column names", () {
      expect(table.getColumnName(0), equals("name"));
      expect(table.getColumnName(1), equals("age"));
    });

    test("have correct column types", () {
      expect(table.getColumnType(0), equals(ValueType.STRING));
      expect(table.getColumnType(1), equals(ValueType.INTEGER));
    });
  });
}

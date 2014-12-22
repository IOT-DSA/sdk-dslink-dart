import "package:dslink/link.dart";

const ValueType LETTER = const ValueType("enum", enumValues: const [
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z"
]);

void main(args) {
  var link = new DSLink("DartSimpleLink", host: "rnd.iot-dsa.org", debug: args.contains("-d") || args.contains("--debug"));

  link.loadNodes([
    {
      "name": "Types",
      "children": [
        {
          "name": "Integer Point 1",
          "value": 1
        },
        {
          "name": "String Point 1",
          "value": "Hello World"
        },
        {
          "name": "Double Point 1",
          "value": 2.352
        },
        {
          "name": "Boolean Point 1",
          "value": true,
          "setter": true
        },
        {
          "name": "Letter Point 1",
          "value": new Value(new DateTime.now(), LETTER, "A"),
          "setter": true
        }
      ],
      "actions": [
        {
          "name": "GetTable",
          "hasTableReturn": true,
          "execute": (args) {
            return new SingleRowTable({
              "Greeting": ValueType.STRING
            }, {
              "Greeting": Value.of("Hello World")
            });
          }
        }
      ]
    }
  ]);
  
  print(link.createBasicLoadNode(link.rootNode));
  
  link.connect().then((_) {
    print("Connected.");
  });
}

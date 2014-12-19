import "dart:html";
import "dart:async";
import "package:dslink/link_browser.dart";

import "dart:math";

DSLink link;
TableElement table;

Timer timer;

void main() {
  var random = new Random();
  link = new DSLink("DartBrowserLink${random.nextInt(255)}", debug: true, host: "rnd.iot-dsa.org");
  table = querySelector("#table");
  
  print("Your link is called '${link.name}'");
  
  querySelector("#connect").onClick.listen((_) {
    link.connect().then((_) {
      print("Connected.");
    });
  });
  
  querySelector("#disconnect").onClick.listen((_) {
    link.disconnect().then((_) {
      print("Disconnected.");
    });
  });
 
  var types = link.createRootNode("Types");
  var integerNode = types.createChild("Integer Point 1", value: 1);
  var stringNode = types.createChild("String Point 1", value: "Hello World");
  var doubleNode = types.createChild("Double Point 1", value: 2.352);
  var boolNode = types.createChild("Boolean Point 1", value: true);
  
  boolNode.createAction("SetValue", params: {
    "value": ValueType.BOOLEAN
  }, execute: (args) {
    boolNode.value = args["value"];
  });
  
  types.createAction("GetTable", hasTableReturn: true, execute: (args) {
    return new SingleRowTable({
      "Greeting": ValueType.STRING
    }, {
      "Greeting": Value.of("Hello World")
    });
  });
  
  timer = new Timer.periodic(new Duration(seconds: 2), (t) {
    table.children.clear();
    table.appendHtml("""
      <tr>
        <th>Name</th>
        <th>Path</th>
        <th>Value</th>
      </tr>
    """);
    var allNodes = getAllNodes(link.rootNode);
    for (var node in allNodes) {
      if (!node.hasValue) continue;
      var row = table.addRow();
     
      var newValue = node.value;
      var lastValue = _values[node.path];
      if (lastValue != null) {
        if (newValue != lastValue) {
          row.classes.add("info");
        }
      }
      
      _values[node.path] = newValue;
      var nameCell = row.addCell();
      var pathCell = row.addCell();
      var valueCell = row.addCell();
      nameCell.text = node.displayName;
      pathCell.text = node.path;
      valueCell.text = newValue != null ? newValue.toString() : "null";
    }
  });
}

Map<String, Value> _values = {};

List<DSNode> getAllNodes(DSNode node) {
  var nodes = [];
  for (var node in node.children.values) {
    nodes.add(node);
    nodes.addAll(getAllNodes(node));
  }
  return nodes;
}
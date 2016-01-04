import "package:dslink/dslink.dart";

LinkProvider link;

main(List<String> args) async {
  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "Actions-", defaultNodes: {
    "message": {
      r"$name": "Message", // The pretty name of this node.
      r"$type": "string", // The type of the node is a string.
      r"$writable": "write", // This node's value can be set by a requester.
      "?value": "Hello World", // The default message value.
      "reset": { // An action on the message node.
        r"$name": "Reset", // The pretty name of this action.
        r"$is": "reset", // This node takes on the 'reset' profile.
        r"$invokable": "write", // Invoking this action requires write permissions.
        r"$params": [], // This action does not have any parameters.
        r"$result": "values", // This action returns a single row of values.
        r"$columns": [] // This action does not return any actual values.
      }
    }
  }, profiles: {
    "reset": (String path) => new ResetNode(path) // The reset profile should use this function to create the node object.
  }, encodePrettyJson: true);

  // Connect to the broker.
  link.connect();

  // Save the message when it changes.
  link.onValueChange("/message").listen((update) => link.save());
}

// A simple node that resets the message value.
class ResetNode extends SimpleNode {
  ResetNode(String path, [SimpleNodeProvider provider]) : super(path, provider) {
    print("========= CREATE RESET =========");
  }

  @override
  onInvoke(Map<String, dynamic> params) {
    link.updateValue("/Message", "Hello World"); // Update the value of the message node.
    return {}; // Return an empty row of values.
  }
}

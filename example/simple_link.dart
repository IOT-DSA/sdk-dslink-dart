import "package:dslink/dslink.dart";

LinkProvider link;

main(List<String> args) async {
  // Process the arguments and initializes the default nodes.
  link = new LinkProvider(args, "Simple-", defaultNodes: {
    "message": {
      r"$name": "Message", // The pretty name of this node.
      r"$type": "string", // The type of the node is a string.
      r"$writable": "write", // This node's value can be set by a requester.
      "?value": "Hello World" // The default message value.
    }
  }, encodePrettyJson: true);

  // Connect to the broker.
  link.connect();

  // Save the message when it changes.
  link.onValueChange("/message").listen((_) => link.save());
}

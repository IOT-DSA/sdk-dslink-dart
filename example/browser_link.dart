import "package:dslink/browser.dart";

LinkProvider link;

main() async {
  link = new LinkProvider(
    "http://127.0.0.1:8080/conn", // Broker URL
    "BrowserExample-", // Link Prefix
    defaultNodes: {
      "Message": {
        r"$type": "string", // The type of the node is a string.
        r"$writable": "write", // This node's value can be set by a requester.
        "?value": "Hello World" // The default message value.
      }
    }
  );

  await link.init(); // Initialize the Link

  link.connect(); // Connect to the Broker
}

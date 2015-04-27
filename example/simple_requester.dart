import "package:dslink/client.dart";
import "package:dslink/requester.dart";

main() async {
  var link = new HttpClientLink(
      "http://127.0.0.1:8080/conn", // Broker URL
      "Simple-Requester-", // DSLink Prefix
      getKeyFromFile(".dslink.key"), // Gets a Private Key from the specified path. If it does not exist, it is generated then saved.
      isResponder: false
  );

  link.connect(); // Connect to the broker.
  Requester requester = await link.onRequesterReady; // Wait for the requester to be ready.

  await for (RequesterListUpdate update in requester.list("/")) { // List the nodes in /
    print("- ${update.node.remotePath}"); // Print the path of each node.
  } // This will not end until you break the for loop. Whenever a node is added or removed to/from the given path, it will receive an update.
}

import "package:dslink/dslink.dart";

LinkProvider link;

main(List<String> args) async {
  link = new LinkProvider(
      args,
      "Simple-Requester-", // DSLink Prefix
      isResponder: false // We are just a requester.
  );

  link.connect(); // Connect to the broker.
  Requester requester = await link.onRequesterReady; // Wait for the requester to be ready.

  await for (RequesterListUpdate update in requester.list("/")) { // List the nodes in /
    print("- ${update.node.remotePath}"); // Print the path of each node.
  } // This will not end until you break the for loop. Whenever a node is added or removed to/from the given path, it will receive an update.
}

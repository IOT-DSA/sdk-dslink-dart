import "package:dslink/browser_client.dart";
import "package:dslink/responder.dart";

BrowserECDHLink link;
SimpleNodeProvider provider;

main() async {
  provider = new SimpleNodeProvider(); // Create a Simple Node Provider

  link = new BrowserECDHLink(
      "http://127.0.0.1:8080/conn", // Broker URL
      "Browser-", // Link Prefix
      await getPrivateKey(), // Handle Private Key management in the browser
      nodeProvider: new SimpleNodeProvider(),
      isRequester: false, // In this instance, we don't want to be a responder
      isResponder: true // We want to be a responder link
  );

  // Connect to the broker.
  link.connect();
}

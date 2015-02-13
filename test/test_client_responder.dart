import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'sample_responder.dart';

main() async {
  PrivateKey key = new PrivateKey.loadFromString('M6S41GAL0gH0I97Hhy7A2-icf8dHnxXPmYIRwem03HE');

  var link = new HttpClientLink('http://localhost:8080/conn', 'test-responder-', key,
      isResponder: true, nodeProvider: new TestNodeProvider());

  link.init();
}

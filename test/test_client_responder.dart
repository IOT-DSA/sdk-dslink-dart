import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'sample_responder.dart';

main() async {
  String str = new File('certs/private_key.txt').readAsStringSync();
  PrivateKey key = new PrivateKey.loadFromString(str);

  var link = new HttpClientLink('http://localhost:8080/conn', 'test-responder-', key,
      isResponder: true, nodeProvider: new TestNodeProvider());

  link.init();
}

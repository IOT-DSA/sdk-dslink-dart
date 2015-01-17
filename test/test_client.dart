import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';

main() async {
  String str = new File('certs/private_key.txt').readAsStringSync();
  PrivateKey key = new PrivateKey.loadFromString(str);

  var link = new HttpClientLink('http://localhost/conn', 'test-client-', key, isRequester: true);

  var requester = await link.onRequesterReady;
  
  var updates = requester.invoke('/', {
    'msg': 'hello world'
  });
  
  await for (var update in updates) {
    print(update.rows);
  }
}

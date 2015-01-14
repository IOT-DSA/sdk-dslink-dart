import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';

void main() {
  String str = new File('certs/private_key.txt').readAsStringSync();
  DsPrivateKey key = new DsPrivateKey.loadFromString(str);

  var clientSession = new DsHttpClientSession('http://localhost/conn', 'test-client-', key, isRequester: true);

  clientSession.onRequesterReady.then((requester) {
    requester.invoke('/', {
      'msg': 'hello world'
    }).listen((update) {
      print(update.rows);
    });
  });
}

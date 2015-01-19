import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'dart:async';

main() async {
  String str = new File('certs/private_key.txt').readAsStringSync();
  PrivateKey key = new PrivateKey.loadFromString(str);

  var link = new HttpClientLink('http://localhost/conn', 'test-client-', key, isRequester: true);
  link.init();
  Requester requester = await link.onRequesterReady;

//  var updates = requester.invoke('/', {
//    'msg': 'hello world'
//  });
//  
//  await for (var update in updates) {
//    print(update.rows);
//  }
  
//  Stream<RequesterListUpdate> updates = requester.list('/');
//
//  await for (RequesterListUpdate update in updates) {
//    print(update.changes);
//  }
  
  Stream<RequesterSubscribeUpdate> updates  = requester.subscribe('/');
  await for (RequesterSubscribeUpdate update in updates) {
    print(update.value);
  }
}

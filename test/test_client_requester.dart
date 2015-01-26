import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'package:dslink/common.dart';
import 'dart:async';
import 'package:cipher/digests/sha384.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cipher/digests/sha256.dart';

main() async {
  String str = new File('certs/private_key.txt').readAsStringSync();
  PrivateKey key = new PrivateKey.loadFromString(str);

  var link = new HttpClientLink('http://localhost:8080/conn', 'test-client-', key,
      isRequester: true);
  link.init();
  Requester requester = await link.onRequesterReady;

//  stdin.listen((data){
//    try {
//      Map m = JSON.decode(UTF8.decode(data));
//      if (m['method'] == 'list') {
//        if (m['path'] is String) {
//          requester.list(m['path']).listen((update){
//            print('list update: ${update.changes}');
//          });
//        }
//      } else if (m['method'] == 'subscribe'){
//        if (m['paths'] is List) {
//          for (String path in m['paths']) {
//            requester.subscribe(path).listen((update){
//              print('subscribe update: ${update.value}');
//            });
//          }
//        }
//      } else if (m['method'] == 'invoke') {
//        if (m['path'] is String && m['params'] is Map) {
//          requester.invoke(m['path'] ,  m['params']).listen((update){
//            print('list update: ${update.updates}');
//          });
//        }
//      } else {
//        print('not supported yet: $m');
//      }
//
//    } catch(err){
//      print(err);
//    }
//  });

//  var updates = requester.invoke('/conns/test-responder-8', {
//    'msg': 'hello world'
//  });
//
//  await for (var update in updates) {
//    print(update.rows);
//  }

//  Stream<RequesterListUpdate> updates = requester.list('/conns/test-responder-p');
//
//  await for (RequesterListUpdate update in updates) {
//    print(update.changes);
//  }

  Stream<ValueUpdate> updates = requester.subscribe('/conns/test-responder-p');
  for (ValueUpdate update in updates) {
    print(update.value);
  }
}

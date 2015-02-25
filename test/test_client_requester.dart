import 'dart:io';
import 'package:dslink/http_client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/requester.dart';
import 'package:dslink/common.dart';
import 'dart:async';

main() async {
  PrivateKey key = new PrivateKey.loadFromString('1aEqqRYk-yf34tcLRogX145szFsdVtrpywDEPuxRQtM BGt1WHhkwCn2nWSDXHTg-IxruXLrPPUlU--0ghiBIQC7HMWWcNQGAoO03l_BQYx7_DYn0sn2gWW9wESbixzWuKg');

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

//  Stream<RequesterListUpdate> updates = requester.list('/conns/locker-f/locker1');
//  await for (RequesterListUpdate update in updates) {
//    print('update ${update.changes}');
//    requester.list('/conns/locker-f/locker1').listen((update1){
//      print('update1 ${update.changes}');
//    });
//    requester.list('/conns/locker-f/locker2').listen((update1){
//      print('update2 ${update.changes}');
//    });
//  }

  Stream<RequesterListUpdate> updates = requester.list('/conns/responder-V/test');
  await for (RequesterListUpdate update in updates) {
    print('is: ${update.node.children['incremental'].configs[r"$is"]}');
    print('type: ${update.node.children['incremental'].configs[r"$type"]}');
  }
  
//  Stream<ValueUpdate> updates = requester.subscribe('/conns/responder-p/test/incremental');
//  updates.listen((update0){
//    print(update0.value);
//  });
//  

}

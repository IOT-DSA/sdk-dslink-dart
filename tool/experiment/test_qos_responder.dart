import "package:dslink/dslink.dart";
import "package:dslink/utils.dart" show BinaryData, ByteDataUtil, DsTimer;
import "package:dslink/src/storage/simple_storage.dart";

import "dart:math" as Math;
import 'dart:typed_data';
import 'dart:async';


LinkProvider link;
int lastNum;
SimpleNode valueNode;



main(List<String> args) {
  Map defaultNodes = {
    'node':{
      r'$type':'string'
    }
  };

  link = new LinkProvider(
      ['-b', 'localhost:8080/conn', '--log', 'finest'], 'qos-resp',
      defaultNodes: defaultNodes);

  if (link.link == null) {
    // initialization failed
    return;
  }

  link.link.responder.initStorage(new SimpleResponderStorage('storage'));

  valueNode = link.getNode('/node');

  new Timer.periodic(new Duration(seconds: 1),(t){
    DateTime d = new DateTime.now();
    valueNode.updateValue('${d.hour}:${d.minute}:${d.second}');
  });

  link.connect();
}

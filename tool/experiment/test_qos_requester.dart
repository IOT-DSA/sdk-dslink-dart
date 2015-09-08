import "package:dslink/dslink.dart";
import "package:dslink/utils.dart" show BinaryData, ByteDataUtil, DsTimer;

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
      ['-b', 'localhost:8080/conn', '--log', 'finest'], 'qos-req',
      defaultNodes: defaultNodes, isResponder:false, isRequester:true);
  if (link.link == null) {
    // initialization failed
    return;
  }

  link.connect();
  link.onRequesterReady.then((Requester req){
    req.subscribe('/downstream/qos-resp/node', (update){
      print(update.value);
    }, 3);
  });
}

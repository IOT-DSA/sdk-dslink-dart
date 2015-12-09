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
      ['-b', 'localhost:8080/conn','--log', 'finest'], 'streamset-req',
      defaultNodes: defaultNodes, isResponder:false, isRequester:true);
  if (link.link == null) {
    // initialization failed
    return;
  }

  link.connect();
  link.onRequesterReady.then((Requester req){
    Request rawreq;
    void fetchReq(Request v){
      rawreq = v;
      int i = 0;
      new Timer.periodic(new Duration(seconds:1), (Timer t){
        rawreq.addReqParams({'Path':'/data/m1',  'Value':++i});
      });
    }
    req.invoke('/data/streamingSet', {'Path':'/data/m1', 'Value':0}, Permission.CONFIG, fetchReq).listen((update){
      print(update.updates);
    });
    
  });
}

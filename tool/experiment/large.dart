import 'package:dslink/client.dart';
import 'package:dslink/utils.dart';
import 'package:dslink/responder.dart';
import 'dart:math' as Math;
import 'dart:async';

LinkProvider link;

main(List<String> args){
  link = new LinkProvider(args, 'large-link-');

  if (link.link == null) {
    // initialization failed
    return;
  }


  for (var x in new List<int>.generate(500, (i) => i)) {
    link.addNode("/Node_${x}", {
      "?value": "node ${x}",
      r"$type": "string"
    });
  }


  link.connect();
}

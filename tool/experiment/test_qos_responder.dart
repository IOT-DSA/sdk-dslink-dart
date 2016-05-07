import "dart:async";

import "package:dslink/dslink.dart";
import "package:dslink/src/storage/simple_storage.dart";

LinkProvider link;
int lastNum;
SimpleNode valueNode;


main(List<String> args) async {
  var defaultNodes = <String, dynamic>{
    'node':{
      r'$type':'string'
    }
  };

  SimpleResponderStorage storage = new SimpleResponderStorage('storage');

  List<ISubscriptionNodeStorage> storedNodes = await storage.load();

  link = new LinkProvider(
    ['-b', 'localhost:8080/conn', '--log', 'finest'],
    'qos-resp',
    defaultNodes: defaultNodes
  );

  if (link.link == null) {
    // initialization failed
    return;
  }

  link.link.responder.initStorage(storage, storedNodes);

  valueNode = link.getNode('/node');

  new Timer.periodic(new Duration(seconds: 1), (t) {
    DateTime d = new DateTime.now();
    valueNode.updateValue('${d.hour}:${d.minute}:${d.second}');
  });

  link.connect();
}

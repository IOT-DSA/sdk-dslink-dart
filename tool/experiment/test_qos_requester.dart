import "package:dslink/dslink.dart";

LinkProvider link;
int lastNum;
SimpleNode valueNode;


main(List<String> args) {
  var defaultNodes = <String, dynamic>{
    'node': {
      r'$type':'string'
    }
  };

  link = new LinkProvider(
    ['-b', 'localhost:8080/conn', '--log', 'finest'], 'qos-req',
    defaultNodes: defaultNodes, isResponder: false, isRequester: true);
  if (link.link == null) {
    // initialization failed
    return;
  }

  link.connect();
  link.onRequesterReady.then((Requester req) {
    req.subscribe('/downstream/qos-resp/node', (update) {
      print(update.value);
    }, 3);
  });
}

import 'package:dslink/client.dart';
import 'package:dslink/src/crypto/pk.dart';
import 'sample_responder.dart';

main() async {
  PrivateKey key = new PrivateKey.loadFromString('9zaOwGO2iXimn4RXTNndBEpoo32qFDUw72d8mteZP9I BJSgx1t4pVm8VCs4FHYzRvr14BzgCBEm8wJnMVrrlx1u1dnTsPC0MlzAB1LhH2sb6FXnagIuYfpQUJGT_yYtoJM');

  var link = new HttpClientLink('http://localhost:8080/conn', 'rick-req-', key,
      isResponder: true, nodeProvider: new TestNodeProvider());

  link.connect();
}

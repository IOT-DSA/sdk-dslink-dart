import "dart:math";

import "package:dslink/dslink.dart";
import "package:dslink/utils.dart";
import "package:logging/logging.dart";

class TestNodeProvider extends NodeProvider {
  TestNode onlyNode = new TestNode('/');

  LocalNode getNode(String path) {
    return onlyNode;
  }
}

class TestNode extends LocalNodeImpl {
  TestNode(String path) : super(path) {
    configs[r'$is'] = 'node';
    configs[r'$test'] = 'hello world';
    configs[r'$type'] = 'number';
    children['node'] = this;
  }
}

main() async {
  Random random = new Random();
  logger.level = Level.WARNING;
  await createLinks();
  Scheduler.every(Interval.TWO_SECONDS, () {
    var pi = 1;
    for (var pair in pairs) {
      if (pair == null) continue;
      var n = random.nextInt(5000);
      expect[pi] = n;
      pair[2]["/node"].updateValue(n);
      pi++;
    }
  });
}

/// TODO, randomly change a value in a node and test if responder can get it;
void changeValue(value, int idx) {
  (pairs[idx][2] as TestNodeProvider).getNode('/node').updateValue(value);
}

Map<int, int> expect = {};

void valueUpdate(Object value, int idx) {
  if (!expect.containsKey(idx)) {
    return;
  }

  if (expect[idx] != value) {
    print("Value Update Invalid for pair ${idx}: we expected ${expect[idx]}, but we got ${value}.");
  }
  expect.remove(idx);
}

createLinks() async {
  while (true) {
    await createLinkPair();
    if (pairIndex > 2000) {
      return;
    }
  }
}

List pairs = [null];
int pairIndex = 1;

PrivateKey key =
  new PrivateKey.loadFromString(
      '9zaOwGO2iXimn4RXTNndBEpoo32qFDUw72d8mteZP9I BJSgx1t4pVm8VCs4FHYzRvr14BzgCBEm8wJnMVrrlx1u1dnTsPC0MlzAB1LhH2sb6FXnagIuYfpQUJGT_yYtoJM');

createLinkPair() async {
  print("Creating Link Pair #${pairIndex}");

  TestNodeProvider provider = new TestNodeProvider();
  var linkResp = new HttpClientLink('http://localhost:8080/conn', 'responder-$pairIndex-', key, isRequester: false, isResponder: true, nodeProvider: provider);
  linkResp.connect();

  var linkReq = new HttpClientLink('http://localhost:8080/conn', 'requester-$pairIndex-', key, isRequester: true);
  linkReq.connect();

  pairs.add([linkResp, linkReq, provider]);
  print("Links Created: ${(pairIndex * 2)}");

  var mine = pairIndex;

  changeValue(0, pairIndex);
  pairIndex++;

  Requester req = await linkReq.onRequesterReady;
  req.subscribe("/conns/responder-$mine/node", (ValueUpdate val) {
    valueUpdate(val.value, mine);
  });

  return null;
}

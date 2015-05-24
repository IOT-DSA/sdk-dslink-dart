import "dart:math";

import "package:dslink/dslink.dart";
import "package:dslink/utils.dart";
import "package:logging/logging.dart";

import "package:args/args.dart";

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

int pairCount = 1000;

Stopwatch stopwatch;

main(List<String> args) async {
  var argp = new ArgParser();
  argp.addOption("pairs", abbr: "p", help: "Number of Link Pairs", defaultsTo: "1000", valueHelp: "pairs");
  var opts = argp.parse(args);

  try {
    pairCount = int.parse(opts["pairs"]);
  } catch (e) {
    print("Invalid Number of Pairs.");
    return;
  }

  Random random = new Random();
  logger.level = Level.WARNING;

  stopwatch = new Stopwatch();

  await createLinks();
  int mm = 0;
  bool ready = false;

  Scheduler.every(Interval.TWO_SECONDS, () {
    if (connectedCount != pairCount) {
      mm++;

      if (mm == 2) {
        print("${connectedCount} of ${pairCount} link pairs are ready.");
        mm = 0;
      }

      return;
    }

    if (!ready) {
      print("All link pairs are now ready. Subscribing requesters to values and starting value updates.");
      ready = true;
    }

    var pi = 1;
    for (var pair in pairs) {
      if (pair == null) continue;

      var n = random.nextInt(5000);
      expect[pi].add(n);
      pair[2]["/node"].updateValue(n);
      pi++;
    }
  });
}

void changeValue(value, int idx) {
  (pairs[idx][2] as TestNodeProvider).getNode('/node').updateValue(value);
}

Map<int, List<int>> expect = {};

void valueUpdate(Object value, int idx) {
  if (!expect.containsKey(idx)) {
    return;
  }

  var l = expect[idx].removeAt(0);

  if (l != value) {
    print("Value Update Invalid for link pair ${idx}: we expected ${l}, but we got ${value}.");
  }
}

createLinks() async {
  print("Creating ${pairCount} link pairs.");
  while (true) {
    await createLinkPair();
    if (pairIndex > pairCount) {
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
  TestNodeProvider provider = new TestNodeProvider();
  var linkResp = new HttpClientLink('http://localhost:8080/conn', 'responder-$pairIndex-', key, isRequester: false, isResponder: true, nodeProvider: provider);

  var linkReq = new HttpClientLink('http://localhost:8080/conn', 'requester-$pairIndex-', key, isRequester: true);
  linkReq.connect();

  pairs.add([linkResp, linkReq, provider]);

  var mine = pairIndex;

  changeValue(0, pairIndex);
  pairIndex++;

  expect[mine] = [0];

  linkResp.connect().then((_) {
    print("Link Pair ${mine} is now ready.");
    connectedCount++;
    linkReq.requester.subscribe("/conns/responder-$mine/node", (ValueUpdate val) {
      valueUpdate(val.value, mine);
    });
  });
}

int connectedCount = 0;

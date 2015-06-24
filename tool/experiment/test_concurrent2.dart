/**
 * this is a modified version of the original test_concurrent.dart
 * it gives the broker more time to handler handshake and not blocking network traffic
 */
import "dart:math";

import "package:dslink/dslink.dart";
import "package:dslink/utils.dart";
import "package:logging/logging.dart";

import "package:args/args.dart";
import 'dart:async';

class TestNodeProvider extends NodeProvider {
  TestNode onlyNode = new TestNode('/');

  LocalNode getNode(String path) {
    return onlyNode;
  }
  IPermissionManager permissions = new DummyPermissionManager();
  Responder createResponder(String dsId) {
    return new Responder(this, dsId);
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
String broker = "http://localhost:8080/conn";
Stopwatch stopwatch;
Random random = new Random();

String prefix = '';
main(List<String> args) async {
  var argp = new ArgParser();
  argp.addOption("pairs", abbr: "p", help: "Number of Link Pairs", defaultsTo: "1000", valueHelp: "pairs");
  argp.addOption("broker", abbr: "b", help: "Broker Url", defaultsTo: "http://localhost:8080/conn", valueHelp: "broker");
  argp.addOption("prefix", abbr: "f", help: "Prefix on DsLink Id", defaultsTo: "", valueHelp: "previx");
    
  var opts = argp.parse(args);

  try {
    pairCount = int.parse(opts["pairs"]);
  } catch (e) {
    print("Invalid Number of Pairs.");
    return;
  }
  try {
    broker = opts["broker"];
  } catch (e) {
    print("Invalid broker");
    return;
  }
  prefix = opts["prefix"];
  
  logger.level = Level.WARNING;

  stopwatch = new Stopwatch();

  createLinks();
  createLinks();
}

bool onCreatedRun = false;

void onCreated() {
  if (onCreatedRun) return;
  onCreatedRun = true;

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

    while (pi <= 5) {
      var rpc = getRandomPair();
      var n = random.nextInt(5000);
      changeValue(n, rpc);
      pi++;
    }
  });
}

int getRandomPair() {
  return random.nextInt(pairCount - 1) + 1;
}

void changeValue(value, int idx) {
  (pairs[idx][2] as TestNodeProvider).getNode('/node').updateValue(value);
}

createLinks() async {
  print("Creating ${pairCount} link pairs.");
  while (true) {
    await createLinkPair();
    if (pairIndex > pairCount) {
      onCreated();
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
  var linkResp = new HttpClientLink(broker, '$prefix-resp-$pairIndex-', key, isRequester: false, isResponder: true, nodeProvider: provider);

  var linkReq = new HttpClientLink(broker, '$prefix-req--$pairIndex-', key, isRequester: true);
  linkReq.connect();

  pairs.add([linkResp, linkReq, provider]);

  var mine = pairIndex;

  changeValue(0, pairIndex);
  pairIndex++;

  await linkResp.connect();
  print("Link Pair ${mine} is now ready.");
  connectedCount++;
  linkReq.requester.subscribe("/conns/$prefix-resp-$mine/node", (ValueUpdate val) {
  });
}

int connectedCount = 0;

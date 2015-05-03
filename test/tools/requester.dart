import "dart:async";
import "dart:io";
import "dart:convert";

import "package:dslink/common.dart";
import "package:dslink/client.dart";
import "package:dslink/requester.dart";
import "package:dslink/utils.dart";

LinkProvider link;

main(List<String> argv) async {
  updateLogLevel("none");

  link = new LinkProvider(argv, "Requester-", isRequester: true, isResponder: false);

  link.connect();

  Requester requester = await link.onRequesterReady;

  var input = stdin.transform(UTF8.decoder).transform(new LineSplitter()).asBroadcastStream();

  while (true) {
    stdout.write("> ");
    var line = await input.first;

    if (line.trim().isEmpty) continue;
    var split = line.split(" ");

    var cmd = split[0];
    var args = split.skip(1).toList();

    if (["list", "ls", "l"].contains(cmd)) {
      if (args.length != 1) {
        print("Usage: ${cmd} <path>");
        continue;
      }

      var path = args[0];
      RequesterListUpdate update = await requester.list(path).first;

      var node = update.node;

      print("Name: ${node.name}");
      print("Configs:");
      for (var key in node.configs.keys) {
        print("  ${key}: ${node.configs[key]}");
      }

      if (node.attributes.isNotEmpty) {
        print("Attributes:");
        for (var key in node.attributes.keys) {
          print("  ${key}: ${node.attributes[key]}");
        }
      }

      if (node.children.isNotEmpty) {
        print("Children:");
        for (var child in node.children.keys) {
          print("  - ${child}");
        }
      }
    } else if (["value", "val", "v"].contains(cmd)) {
      if (args.length == 0) {
        print("Usage: ${cmd} <path>");
        continue;
      }

      var path = args.join(" ");
      var completer = new Completer<ValueUpdate>.sync();
      ReqSubscribeListener listener;

      listener = requester.subscribe(path, (ValueUpdate update) {
        listener.cancel();
        completer.complete(update);
      });

      try {
        ValueUpdate update = await completer.future.timeout(new Duration(seconds: 5), onTimeout: () {
          listener.cancel();
          throw new Exception("ERROR: Timed out while attempting to get the value.");
        });
        print(update.value);
      } catch (e) {
        print(e.toString());
      }
    } else if (["set", "s"].contains(cmd)) {
      if (args.length < 2) {
        print("Usage: ${cmd} <path> <value>");
        continue;
      }

      var path = args[0];
      var value = args.skip(1).join(" ");
      try {
        value = num.parse(value.toString());
      } catch (e) {}
      try {
        value = JSON.decode(value.toString());
      } catch (e) {}
      await requester.set(path, value);
    } else if (["q", "quit", "exit", "end", "finish", "done"].contains(cmd)) {
      exit(0);
    }
  }
}

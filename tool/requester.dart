import "dart:async";
import "dart:io";
import "dart:convert";

import "package:dslink/dslink.dart";

LinkProvider link;

main(List<String> argv) async {
  updateLogLevel("OFF");

  link = new LinkProvider(argv, "Requester-", isRequester: true, isResponder: false, defaultLogLevel: "OFF");
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
      var name = node.configs.containsKey(r"$name") ? node.configs[r"$name"] : node.name;

      print("Name: ${name}");
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
      var value = parseInputValue(args.skip(1).join(" "));
      await requester.set(path, value);
    } else if (["q", "quit", "exit", "end", "finish", "done"].contains(cmd)) {
      exit(0);
    } else if (["i", "invoke", "call"].contains(cmd)) {
      if (args.length == 0) {
        print("Usage: ${cmd} <path> [values]");
        continue;
      }

      var path = args[0];
      var value = args.length > 1 ? parseInputValue(args.skip(1).join(" ")) : {};

      List<RequesterInvokeUpdate> updates = await requester.invoke(path, value).toList();

      if (updates.length == 1 && updates.first.rows.length == 1) { // Single Row of Values
        var update = updates.first;
        var rows = update.rows;
        var values = rows.first;

        if (update.columns.isNotEmpty) {
          var i = 0;
          for (var x in update.columns) {
            print("${x.name}: ${values[i]}");
            i++;
          }
        } else if (update.columns.isEmpty && values.isNotEmpty) {
          print(values);
        }
      } else {
        var x = [];
        for (var update in updates) {
          x.add(update.updates);
        }
        print(encodePrettyJson(x));
      }
    }
  }
}

String encodePrettyJson(input) => new JsonEncoder.withIndent("  ").convert(input);

dynamic parseInputValue(String input) {
  var number = num.parse(input, (_) => null);
  if (number != null) {
    return number;
  }

  var lower = input.toLowerCase();

  if (lower == "true" || lower == "false") {
    return lower == "true";
  }

  try {
    return JSON.decode(input);
  } catch (e) {}

  return input;
}

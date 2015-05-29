import "dart:async";
import "dart:io";
import "dart:convert";

import "package:dslink/dslink.dart";
import "package:dslink/io.dart";

LinkProvider link;

main(List<String> argv) async {
  updateLogLevel("OFF");

  link = new LinkProvider(argv, "Requester-", isRequester: true, isResponder: false, defaultLogLevel: "OFF");
  link.connect();

  Requester requester = await link.onRequesterReady;

  var input = readStdinLines().asBroadcastStream();

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
        for (var id in node.children.keys) {
          RemoteNode child = node.getChild(id);
          var cn = child.configs.containsKey(r"$name") ? child.configs[r"$name"] : child.name;
          print("  - ${cn}${cn != child.name ? ' (${child.name})' : ''}");
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
        var c = updates.last.columns;
        var x = [];
        for (var update in updates) {
          x.addAll(update.updates);
        }
        //print(encodePrettyJson(x));
        print(buildTableTree(c, x));
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

class Icon {
  static const String CHECKMARK = "\u2713";
  static const String BALLOT_X = "\u2717";
  static const String VERTICAL_LINE = "\u23D0";
  static const String HORIZONTAL_LINE = "\u23AF";
  static const String LEFT_VERTICAL_LINE = "\u23B8";
  static const String LOW_LINE = "\uFF3F";
  static const String PIPE_VERTICAL = "\u2502";
  static const String PIPE_LEFT_HALF_VERTICAL = "\u2514";
  static const String PIPE_LEFT_VERTICAL = "\u251C";
  static const String PIPE_HORIZONTAL = "\u2500";
  static const String PIPE_BOTH = "\u252C";
  static const String HEAVY_VERTICAL_BAR = "\u275A";
  static const String REFRESH = "\u27F3";
  static const String HEAVY_CHECKMARK = "\u2714";
  static const String HEAVY_BALLOT_X = "\u2718";
  static const String STAR = "\u272D";
}

String buildTableTree(List<TableColumn> columns, List<List<dynamic>> rows) {
  List<Map<String, dynamic>> nodes = [];
  var map = {
    "label": "Result",
    "nodes": nodes
  };

  var i = 0;
  for (var row in rows) {
    var n = [];

    var x = 0;
    for (var value in row) {
      String name;
      if (x >= columns.length) {
        name = "";
      } else {
        name = columns[x].name;
      }

      n.add({
        "label": name,
        "nodes": [value.toString()]
      });
      x++;
    }

    nodes.add({
      "label": i.toString(),
      "nodes": n
    });
    i++;
  }

  return createTreeView(map);
}

String createTreeView(input, {String prefix: '', Map opts}) {
  if (input is String) {
    input = {
      "label": input
    };
  }

  var label = input.containsKey("label") ? input['label'] : "";
  var nodes = input.containsKey("nodes") ? input['nodes'] : [];

  var lines = label.split("\n");
  var splitter = '\n' + prefix + (nodes.isNotEmpty ? Icon.PIPE_VERTICAL : ' ') + ' ';

  return prefix + lines.join(splitter) + '\n' + nodes.map((node) {
    var last = nodes.last == node;
    var more = node is Map && node.containsKey("nodes") && node['nodes'] is List && node['nodes'].isNotEmpty;
    var prefix_ = prefix + (last ? ' ' : Icon.PIPE_VERTICAL) + ' ';

    return prefix
    + (last ? Icon.PIPE_LEFT_HALF_VERTICAL : Icon.PIPE_LEFT_VERTICAL) + Icon.PIPE_HORIZONTAL
    + (more ? Icon.PIPE_BOTH : Icon.PIPE_HORIZONTAL) + ' '
    + createTreeView(node, prefix: prefix_, opts: opts).substring(prefix.length + 2);
  }).join('');
}

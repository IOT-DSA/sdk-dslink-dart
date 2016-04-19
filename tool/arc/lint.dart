import "dart:async";
import "dart:io";

import "package:path/path.dart" as pathlib;

const bool enableLintMode = false;
const bool enableStrongMode = false;

const List<String> alwaysIgnoreFiles = const [];

const Map<String, String> friendlyMessageMap = const {
  "Unnecessary brace in string interp": "Unnecessary brace in"
    " string interpolation"
};

const Map<String, String> severityLevels = const {
  "WARNING": "warning",
  "INFO": "advice",
  "ERROR": "error"
};

const List<String> ignoreMessages = const [
  "Unnecessary brace in string interpolation"
];

main(List<String> files) async {
  if (files.isEmpty) {
    return;
  }

  var args = ["--format=machine"];

  if (enableLintMode) {
    args.add("--lints");
  }

  if (enableStrongMode) {
    args.add("--strong");
  }

  args.addAll(files);

  var result = await Process.run("dartanalyzer", args);

  List<String> lines = [];
  lines.addAll(result.stdout.toString().split("\n"));
  lines.addAll(result.stderr.toString().split("\n"));

  List<String> figureItOut = [];

  for (String line in lines) {
    line = line.trim();

    if (line.contains("is a part and cannot be analyzed")) {
      var path = line.split(" is a part").first.trim();
      figureItOut.add(path);
      continue;
    }

    if (line == "Please pass in a library that contains this part.") {
      continue;
    }

    if (line.isEmpty) continue;

    List<String> parts = line.split("|");

    String severity = severityLevels[parts[0]];
    String name = parts[2];

    name = name.toLowerCase().replaceAll("_", " ");
    name = name[0].toUpperCase() + name.substring(1);

    if (friendlyMessageMap.containsKey(name)) {
      name = friendlyMessageMap[name];
    }

    String path = parts[3];
    int lineNumber = int.parse(parts[4]);
    int columnNumber = int.parse(parts[5]);
    String message = parts[7];

    path = pathlib.relative(path, from: Directory.current.path);
    if (alwaysIgnoreFiles.contains(path)) {
      severity = "disabled";
    }

    if (ignoreMessages.contains(name)) {
      severity = "disabled";
    }

    print("${severity} !!${path}!!"
      " !!${name}!! ${lineNumber}:${columnNumber}"
      " !!${message}!!");
  }

  for (String path in figureItOut) {
    await lookForRealFileAndAnalyze(path);
  }
}

Future lookForRealFileAndAnalyze(String path) async {
  var file = new File(path);
  var content = await file.readAsString();
  var firstLine = content.trim().split("\n").first;
  if (!firstLine.startsWith("part of ")) {
    return;
  }

  var lib = firstLine.split("part of ").last.trim();
  if (lib.endsWith(";")) {
    lib = lib.substring(0, lib.length - 1);
  }

  var dir = new Directory("lib");
  var files = await dir.list(recursive: true).where((entity) {
    return entity is File && entity.path.endsWith(".dart");
  }).toList();

  for (File file in files) {
    var lines = await file.readAsLines();
    var line = lines.where((line) => line.trim().isNotEmpty).first;

    if (line.startsWith("library ${lib};")) {
      await main([
        file.path
      ]);
      return;
    }
  }
}

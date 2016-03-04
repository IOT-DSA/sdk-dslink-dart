import "dart:io";

const Map<String, String> SEVERITY = const {
  "WARNING": "warning",
  "INFO": "advice",
  "ERROR": "error"
};

main(List<String> files) async {
  if (files.isEmpty) {
    return;
  }

  var result = await Process.run("dartanalyzer", [
    "--format=machine",
  ]..addAll(files));

  List<String> lines = [];
  lines.addAll(result.stdout.toString().split("\n"));
  lines.addAll(result.stderr.toString().split("\n"));

  for (String line in lines) {
    line = line.trim();

    if (line.isEmpty) continue;

    List<String> parts = line.split("|");

    String severity = SEVERITY[parts[0]];
    String name = parts[2];

    name = name.toLowerCase().replaceAll("_", " ");
    name = name[0].toUpperCase() + name.substring(1);

    String path = parts[3];
    int lineNumber = int.parse(parts[4]);
    int columnNumber = int.parse(parts[5]);
    String message = parts[7];

    print("${severity} !!${path}!!"
      " !!${name}!! ${lineNumber}:${columnNumber}"
      " !!${message}!!");
  }
}
